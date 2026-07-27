#!/usr/bin/env bash
set -euo pipefail

: "${PROVIDER:?}"
: "${MODEL:?}"
: "${MODEL_API_KEY:?}"
: "${CONSUMER_WORKSPACE:?}"
: "${PROMPT_FILE:?}"
: "${SCHEMA_FILE:?}"
: "${RESULT_FILE:?}"
: "${GITHUB_ACTION_PATH:?}"

case "$PROVIDER" in
  codex|claude) ;;
  *) echo "::error::Unsupported provider: $PROVIDER"; exit 1 ;;
esac
test -d "$CONSUMER_WORKSPACE"
test -s "$PROMPT_FILE"
test -s "$SCHEMA_FILE"
command -v pkill >/dev/null

proxy_script="$GITHUB_ACTION_PATH/../../scripts/agentic/model-api-proxy.py"
test -f "$proxy_script"
agent_user=ctex-agent
session_dir=$(mktemp -d /tmp/ctex-agent-session.XXXXXX)
agent_home="$session_dir/home"
proxy_ready="$session_dir/proxy-url"
proxy_log="$session_dir/proxy.log"
secret_file="/run/ctex-agent-model-key-$$"
proxy_pid=
workspace_uid=$(stat -c '%u' "$CONSUMER_WORKSPACE")
workspace_gid=$(stat -c '%g' "$CONSUMER_WORKSPACE")

cleanup() {
  set +e
  # Agent 启动的后台子进程不能越过本次模型会话继续运行。
  sudo --non-interactive pkill -KILL -u "$agent_user" 2>/dev/null || true
  if [[ -n "$proxy_pid" ]]; then
    sudo --non-interactive kill "$proxy_pid" 2>/dev/null || true
  fi
  sudo --non-interactive rm -f -- "$secret_file"
  # GitHub 的后续步骤仍以 runner 用户运行；恢复 fresh checkout 的统一所有权。
  sudo --non-interactive chown -hR "$workspace_uid:$workspace_gid" "$CONSUMER_WORKSPACE"
  sudo --non-interactive chmod -R u+rwX "$CONSUMER_WORKSPACE"
  rm -rf -- "$session_dir"
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

mkdir -p "$agent_home"
cp -- "$PROMPT_FILE" "$agent_home/prompt.txt"
cp -- "$SCHEMA_FILE" "$agent_home/schema.json"
touch "$agent_home/raw-result.json"
chmod 755 "$session_dir"
sudo --non-interactive chown -R "$agent_user:$agent_user" "$agent_home"

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
sudo --non-interactive python3 "$proxy_script" \
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
)

case "$PROVIDER" in
  codex)
    codex_path=/tmp/ctex-agent-cli/codex-0.145.0/node_modules/.bin/codex
    test -x "$codex_path"
    cat > "$agent_home/config.toml" <<EOF
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
      exec
      --cd "$CONSUMER_WORKSPACE"
      --skip-git-repo-check
      --ephemeral
      --dangerously-bypass-approvals-and-sandbox
      --output-schema "$agent_home/schema.json"
      --output-last-message "$agent_home/raw-result.json"
    )
    if [[ ${IGNORE_REPOSITORY_RULES:-false} == true ]]; then
      codex_args+=(--ignore-rules)
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
    schema=$(jq -c . "$agent_home/schema.json")
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
      "$agent_home/claude-result.json" \
      node "$wrapper" -p \
      --bare \
      --no-session-persistence \
      --model "$MODEL" \
      --dangerously-skip-permissions \
      --output-format json \
      --json-schema "$schema"
    jq -e '(.is_error? // false) == false' "$agent_home/claude-result.json" > /dev/null
    jq -c '
      if (.structured_output? | type) == "object" then .structured_output
      elif type == "object" then .
      else error("Claude did not return a structured object")
      end
    ' "$agent_home/claude-result.json" > "$agent_home/raw-result.json"
    ;;
esac

test -s "$agent_home/raw-result.json"
jq -e 'type == "object"' "$agent_home/raw-result.json" > /dev/null
mkdir -p "$(dirname "$RESULT_FILE")"
cp -- "$agent_home/raw-result.json" "$RESULT_FILE"
