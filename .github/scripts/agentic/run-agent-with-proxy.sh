#!/usr/bin/env bash
set -euo pipefail

: "${PROVIDER:?}"
: "${MODEL:?}"
: "${MODEL_API_KEY:?}"
: "${CONSUMER_WORKSPACE:?}"
: "${PROMPT_FILE:?}"
: "${SCHEMA_FILE:?}"
: "${RESULT_FILE:?}"
: "${MODEL_PROXY_SCRIPT:?}"
: "${CONTROL_HARDENING_LIBRARY:?}"

case "$PROVIDER" in
  codex|claude) ;;
  *) echo "::error::Unsupported provider: $PROVIDER"; exit 1 ;;
esac
test -d "$CONSUMER_WORKSPACE"
test -s "$PROMPT_FILE"
test -s "$SCHEMA_FILE"
command -v pkill >/dev/null

proxy_script=$MODEL_PROXY_SCRIPT
test -f "$proxy_script"
control_hardening_library=$CONTROL_HARDENING_LIBRARY
test -f "$control_hardening_library"
agent_user=ctex-agent
session_dir=$(sudo --non-interactive mktemp -d /run/ctex-agent-session.XXXXXX)
agent_home="$session_dir/home"
agent_root="$session_dir/work-root"
control_dir="$session_dir/control"
control_result="$control_dir/raw-result.json"
proxy_ready="$session_dir/proxy-url"
proxy_log="$session_dir/proxy.log"
secret_file="/run/ctex-agent-model-key-$$"
proxy_pid=
workspace_uid=$(stat -c '%u' "$CONSUMER_WORKSPACE")
workspace_gid=$(stat -c '%g' "$CONSUMER_WORKSPACE")

stop_agent_processes() {
  # CLI 退出后，先结束所有仓库代码留下的同 UID 进程，才读取受保护的结果通道。
  for _ in {1..100}; do
    if ! pgrep -u "$agent_user" >/dev/null 2>&1; then
      return 0
    fi
    sudo --non-interactive pkill -KILL -u "$agent_user" 2>/dev/null || true
    sleep 0.01
  done
  echo "::error::$agent_user 仍有后台进程，拒绝读取 Agent 结果"
  return 1
}

cleanup() {
  set +e
  # Agent 启动的后台子进程不能越过本次模型会话继续运行。
  stop_agent_processes || true
  if [[ -n "$proxy_pid" ]]; then
    sudo --non-interactive kill "$proxy_pid" 2>/dev/null || true
  fi
  sudo --non-interactive rm -f -- "$secret_file"
  # GitHub 的后续步骤仍以 runner 用户运行；恢复 fresh checkout 的统一所有权。
  sudo --non-interactive chown -hR "$workspace_uid:$workspace_gid" "$CONSUMER_WORKSPACE"
  sudo --non-interactive chmod -R u+rwX "$CONSUMER_WORKSPACE"
  sudo --non-interactive rm -rf -- "$session_dir"
}
trap cleanup EXIT

if ! id "$agent_user" >/dev/null 2>&1; then
  sudo --non-interactive useradd --system --create-home --user-group "$agent_user"
fi
if id -nG "$agent_user" | tr ' ' '\n' | grep -Eq '^(sudo|admin|wheel|root)$'; then
  echo "::error::$agent_user 不得属于特权用户组"
  exit 1
fi
if sudo --non-interactive -u "$agent_user" sudo --non-interactive true 2>/dev/null; then
  echo "::error::$agent_user 不得取得 sudo 权限"
  exit 1
fi

sudo --non-interactive install -d -o root -g root -m 711 "$session_dir"
sudo --non-interactive install -d -o "$agent_user" -g "$agent_user" -m 700 \
  "$agent_home" "$agent_root" "$control_dir"
sudo --non-interactive install -o "$workspace_uid" -g "$workspace_gid" -m 600 \
  /dev/null "$proxy_log"
sudo --non-interactive install -o root -g root -m 600 \
  "$PROMPT_FILE" "$agent_home/prompt.txt"
sudo --non-interactive install -o "$agent_user" -g "$agent_user" -m 600 \
  "$SCHEMA_FILE" "$agent_home/schema.json"
sudo --non-interactive install -o "$agent_user" -g "$agent_user" -m 600 \
  /dev/null "$control_result"

if [[ ${IGNORE_REPOSITORY_RULES:-false} == true ]]; then
  : "${TRUSTED_INSTRUCTION_DIR:?}"
  for trusted_instruction in pr-review.md github-comment.md; do
    trusted_path="$TRUSTED_INSTRUCTION_DIR/$trusted_instruction"
    test -f "$trusted_path" && test ! -L "$trusted_path"
    if sudo --non-interactive -u "$agent_user" test -w "$trusted_path"; then
      echo "::error::Agent 用户不得修改可信审查规范 $trusted_path"
      exit 1
    fi
  done
  if sudo --non-interactive -u "$agent_user" test -w "$TRUSTED_INSTRUCTION_DIR"; then
    echo "::error::Agent 用户不得修改可信审查规范目录"
    exit 1
  fi
  sudo --non-interactive sed -i \
    "s|@@TRUSTED_INSTRUCTION_DIR@@|$TRUSTED_INSTRUCTION_DIR|g" \
    "$agent_home/prompt.txt"
  if sudo --non-interactive grep -Fq '@@TRUSTED_INSTRUCTION_DIR@@' \
    "$agent_home/prompt.txt"; then
    echo "::error::可信审查规范路径占位符未完全替换"
    exit 1
  fi
fi
sudo --non-interactive chown "$agent_user:$agent_user" "$agent_home/prompt.txt"

# 模型密钥只写入 root 可读文件。代理就绪后立即删除该文件；密钥只留在
# root 代理进程内存中，Agent 进程只会看到下面的无意义占位值。
printf '%s' "$MODEL_API_KEY" | sudo --non-interactive install -m 600 /dev/stdin "$secret_file"
unset MODEL_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN

upstream=${MODEL_BASE_URL:-https://llm.fantacy.live}
if [[ "$PROVIDER" == codex && "$upstream" != */v1 ]]; then
  upstream="${upstream%/}/v1"
fi
# 日志文件由 runner shell 有意创建，不含凭据。
# shellcheck disable=SC2024
sudo --non-interactive env -i PATH=/usr/bin:/bin LANG=C.UTF-8 \
  python3 "$proxy_script" \
  --provider "$PROVIDER" \
  --upstream "$upstream" \
  --secret-file "$secret_file" \
  --ready-file "$proxy_ready" \
  >"$proxy_log" 2>&1 &
proxy_pid=$!

for _ in {1..100}; do
  [[ -s "$proxy_ready" ]] && break
  sudo --non-interactive kill -0 "$proxy_pid" 2>/dev/null || {
    sudo --non-interactive cat "$proxy_log" || true
    echo "::error::本地模型代理启动失败"
    exit 1
  }
  sleep 0.1
done
test -s "$proxy_ready"
proxy_url=$(<"$proxy_ready")
sudo --non-interactive rm -f -- "$secret_file"

# 两条检查固定真正的权限边界：Agent 用户既读不到 root 代理的环境，也没有 sudo。
if sudo --non-interactive -u "$agent_user" test -r "/proc/$proxy_pid/environ"; then
  echo "::error::Agent 用户不应读取模型代理环境"
  exit 1
fi
# 代理已经从可信脚本启动并删掉了密钥文件，此后才把审查工作树交给 Agent。
sudo --non-interactive chown -hR "$agent_user:$agent_user" "$CONSUMER_WORKSPACE"

safe_path=$PATH
common_env=(
  env -i
  "HOME=$agent_home"
  "PATH=$safe_path"
  "LANG=C.UTF-8"
  "LC_ALL=C.UTF-8"
  "CI=true"
  "GITHUB_WORKSPACE=$CONSUMER_WORKSPACE"
  "RUNNER_TEMP=$agent_home"
  "LD_PRELOAD=$control_hardening_library"
)

case "$PROVIDER" in
  codex)
    codex_path=/tmp/ctex-agent-cli/codex-0.145.0/node_modules/.bin/codex
    test -x "$codex_path"
    sudo --non-interactive tee "$agent_home/config.toml" > /dev/null <<EOF
model = "$MODEL"
model_provider = "local_proxy"

[model_providers.local_proxy]
name = "ctex-kit local credential proxy"
base_url = "$proxy_url"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
EOF
    sudo --non-interactive chown "$agent_user:$agent_user" "$agent_home/config.toml"
    codex_args=(
      --ask-for-approval never
      --sandbox workspace-write
      exec
      --skip-git-repo-check
      --ephemeral
      --output-schema "$agent_home/schema.json"
      --output-last-message "$control_result"
    )
    if [[ ${IGNORE_REPOSITORY_RULES:-false} == true ]]; then
      # Codex 只从主工作根发现 AGENTS.md；不可信 checkout 仅作为显式附加目录。
      # --ignore-rules 另外禁用 checkout 或用户提供的 execpolicy .rules 文件。
      codex_args+=(--cd "$agent_root" --add-dir "$CONSUMER_WORKSPACE" --ignore-rules)
    else
      codex_args+=(--cd "$CONSUMER_WORKSPACE")
    fi
    sudo --non-interactive -u "$agent_user" -- \
      "${common_env[@]}" \
      OPENAI_API_KEY=ctex-local-proxy \
      CODEX_HOME="$agent_home" \
      bash -c 'prompt=$1; shift; exec "$@" < "$prompt"' bash \
      "$agent_home/prompt.txt" "$codex_path" "${codex_args[@]}" -
    ;;
  claude)
    wrapper=/tmp/ctex-agent-cli/claude-code-2.1.148/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs
    test -f "$wrapper"
    schema=$(sudo --non-interactive jq -c . "$agent_home/schema.json")
    sudo --non-interactive tee "$agent_home/claude-settings.json" > /dev/null <<'EOF'
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false
  },
  "permissions": {
    "defaultMode": "dontAsk"
  }
}
EOF
    sudo --non-interactive chown "$agent_user:$agent_user" "$agent_home/claude-settings.json"
    sudo --non-interactive -u "$agent_user" -- \
      "${common_env[@]}" \
      ANTHROPIC_API_KEY=ctex-local-proxy \
      ANTHROPIC_AUTH_TOKEN=ctex-local-proxy \
      ANTHROPIC_BASE_URL="$proxy_url" \
      'ANTHROPIC_CUSTOM_HEADERS=Authorization: Bearer ctex-local-proxy' \
      DISABLE_AUTOUPDATER=1 \
      DISABLE_TELEMETRY=1 \
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
      bash -c '
        workspace=$1
        prompt=$2
        output=$3
        shift 3
        cd "$workspace"
        exec "$@" < "$prompt" > "$output"
      ' bash "$CONSUMER_WORKSPACE" "$agent_home/prompt.txt" \
      "$control_dir/claude-result.json" \
      node "$wrapper" -p \
      --bare \
      --no-session-persistence \
      --model "$MODEL" \
      --permission-mode dontAsk \
      --settings "$agent_home/claude-settings.json" \
      --output-format json \
      --json-schema "$schema"
    stop_agent_processes
    sudo --non-interactive jq -e '(.is_error? // false) == false' \
      "$control_dir/claude-result.json" > /dev/null
    sudo --non-interactive jq -c '
      if (.structured_output? | type) == "object" then .structured_output
      elif type == "object" then .
      else error("Claude did not return a structured object")
      end
    ' "$control_dir/claude-result.json" | \
      sudo --non-interactive tee "$control_result" > /dev/null
    ;;
esac

# Codex 返回后也必须先结束全部同 UID 后台进程。Claude 路径在规范化前已经执行过；
# 此处再执行一次，固定读取结果前没有任何 Agent 进程存活。
stop_agent_processes
sudo --non-interactive test -s "$control_result"
sudo --non-interactive jq -e 'type == "object"' "$control_result" > /dev/null
mkdir -p "$(dirname "$RESULT_FILE")"
sudo --non-interactive install -o "$workspace_uid" -g "$workspace_gid" -m 600 \
  "$control_result" "$RESULT_FILE"
