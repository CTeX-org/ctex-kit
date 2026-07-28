#!/usr/bin/env bash
# 为 Agent job 安装排版、PDF 和图像工具。
#
# Agent 需要自己跑 l3build、编译 MWE、把 PDF 转成图片比对，因此这些工具必须在
# Agent 启动前就绪。调用方负责 actions/cache 的 restore 与 save（cache action
# 无法在脚本内调用），本脚本只负责安装并校验。
#
# 需要的环境变量：
#   TL_VERSION       TeX Live 年度版本
#   TL_PACKAGE_FILE  TeX Live 包清单路径
#   FONT_URL_FILE    CJK 字体下载清单路径
# 可选：
#   FONT_CACHE       CJK 字体缓存目录，默认 $GITHUB_WORKSPACE/.font-cache
#   XECJK_FONT_CACHE xeCJK 文档字体缓存目录，默认 $GITHUB_WORKSPACE/.xecjk-font-cache

set -euo pipefail

: "${TL_VERSION:?}"
: "${TL_PACKAGE_FILE:?}"
: "${FONT_URL_FILE:?}"
font_cache="${FONT_CACHE:-$GITHUB_WORKSPACE/.font-cache}"
xecjk_font_cache="${XECJK_FONT_CACHE:-$GITHUB_WORKSPACE/.xecjk-font-cache}"

sudo apt-get update -q
sudo apt-get install -y --no-install-recommends \
  fonts-freefont-ttf \
  fontconfig \
  ghostscript \
  imagemagick \
  poppler-utils \
  python3-yaml \
  shellcheck \
  unzip

# TeX Live：缓存命中时只需导出 PATH，未命中时由调用方的 setup-texlive 步骤安装。
tl_bin="$RUNNER_TEMP/setup-texlive-action/$TL_VERSION/bin/x86_64-linux"
if [[ -x "$tl_bin/tlmgr" ]]; then
  echo "$tl_bin" >> "$GITHUB_PATH"
  export PATH="$tl_bin:$PATH"
fi
if ! command -v tlmgr > /dev/null; then
  echo "::error::TeX Live 不可用；调用方必须在本步骤前恢复缓存或安装 TeX Live。"
  exit 1
fi
command -v l3build
command -v xelatex

# 字体：缓存未命中时下载并解出 TTC/TTF，命中时直接使用。
mkdir -p "$font_cache"
if [[ ! -f "$font_cache/.done" ]]; then
  font_url_file="$FONT_URL_FILE"
  [[ "$font_url_file" == /* ]] || font_url_file="$GITHUB_WORKSPACE/$font_url_file"
  (
    cd "$font_cache"
    while IFS= read -r url || [[ -n "$url" ]]; do
      url=${url%$'\r'}
      case "$url" in '' | '#'*) continue ;; esac
      curl --fail --location --remote-name "$url"
    done < "$font_url_file"
    for archive in *OTC.zip; do
      unzip -ojd . "$archive" '*.ttc'
    done
    rm -f -- *.zip
    touch .done
  )
fi

mkdir -p "$xecjk_font_cache"
if [[ ! -f "$xecjk_font_cache/.done" ]]; then
  (
    cd "$xecjk_font_cache"
    curl --fail --location --output HanaMinB.ttf \
      'https://github.com/googlefonts/chinese/raw/gh-pages/fonts/HanaMin/HanaMinB.ttf'
    curl --fail --location --remote-name \
      'https://github.com/notofonts/symbols/releases/download/NotoSansSymbols2-v2.008/NotoSansSymbols2-v2.008.zip'
    for archive in NotoSansSymbols2-*.zip; do
      unzip -ojd . "$archive" '*.ttf'
    done
    rm -f -- *.zip
    touch .done
  )
fi

shopt -s nullglob
sans_fonts=("$font_cache"/NotoSansCJK-*.ttc)
serif_fonts=("$font_cache"/NotoSerifCJK-*.ttc)
if (( ${#sans_fonts[@]} == 0 || ${#serif_fonts[@]} == 0 )); then
  echo '::error::CJK 字体缓存不完整。'
  exit 1
fi
for required in HanaMinB.ttf NotoSansSymbols2-Regular.ttf; do
  if [[ ! -f "$xecjk_font_cache/$required" ]]; then
    echo "::error::xeCJK 字体缓存缺少文件：$required"
    exit 1
  fi
done

sudo mkdir -p /usr/share/fonts/truetype
sudo cp -- "${sans_fonts[@]}" "${serif_fonts[@]}" /usr/share/fonts/truetype/
sudo cp -- "$xecjk_font_cache"/*.ttf /usr/share/fonts/truetype/

# 让 fontconfig 也能找到 TeX Live 自带的 OpenType 字体，供 MWE 直接按名调用。
# awk 读完全部输出再取值：本脚本带 pipefail，提前 exit 会让 tlmgr 收到 SIGPIPE。
tl_root=$(tlmgr conf \
  | awk -F= '/TEXMFDIST/ && !found {gsub(/^[ \t]+|[ \t]+$/,"",$2);value=$2;found=1} END{print value}')
if [[ -n "$tl_root" && -d "$tl_root/fonts/opentype" ]]; then
  sudo mkdir -p /etc/fonts/conf.d
  sudo tee /etc/fonts/conf.d/09-texlive-opentype.conf > /dev/null <<FONTCONFIG_EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>${tl_root}/fonts/opentype</dir>
  <dir>${tl_root}/fonts/truetype</dir>
</fontconfig>
FONTCONFIG_EOF
else
  echo "::warning::TeX Live 字体目录不存在：$tl_root/fonts/opentype"
fi
fc-cache -f

# ImageMagick 7 的 magick 入口在 runner 上可能缺失，用 v6 子命令补一个等价入口。
compat_dir="$RUNNER_TEMP/ctex-kit-agent-tools/compat-bin"
mkdir -p "$compat_dir"
if ! command -v magick > /dev/null 2>&1; then
  cat > "$compat_dir/magick" <<'MAGICK_EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  compare|composite|identify|mogrify|montage)
    command=$1
    shift
    exec "$command" "$@"
    ;;
  *)
    exec convert "$@"
    ;;
esac
MAGICK_EOF
  chmod +x "$compat_dir/magick"
fi
echo "$compat_dir" >> "$GITHUB_PATH"
export PATH="$compat_dir:$PATH"

# Agent 审查改动 workflow 的 PR 时需要 actionlint。
actionlint_dir="$RUNNER_TEMP/ctex-kit-agent-tools/actionlint-1.7.7"
mkdir -p "$actionlint_dir"
GOBIN="$actionlint_dir" go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.7
echo "$actionlint_dir" >> "$GITHUB_PATH"
export PATH="$actionlint_dir:$PATH"

# ctex 手册的索引由 zhmakeindex 生成，缺它时 l3build doc 会在生成 PDF 之后失败。
# 安装方式与 _check-doc-package.yml、release.yml 保持一致。
zhmk_version=$(curl -fsSL \
  'https://api.github.com/repos/Liam0205/zhmakeindex/releases/latest' \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
if [[ -z "$zhmk_version" ]]; then
  echo '::error::无法取得 zhmakeindex 的最新版本号。'
  exit 1
fi
zhmk_url="https://github.com/Liam0205/zhmakeindex/releases/download/${zhmk_version}/zhmakeindex_${zhmk_version#v}_linux_amd64.tar.gz"
curl -fsSL "$zhmk_url" | sudo tar xz -C /usr/local/bin zhmakeindex

for tool in \
  actionlint fc-match gs kpsewhich l3build magick pdfcrop \
  pdffonts pdfimages pdfinfo pdftoppm pdftotext sha256sum \
  shellcheck texlua xdvipdfmx xelatex zhmakeindex; do
  command -v "$tool"
done
xelatex --version | head -n 1
l3build --version
magick -version | head -n 1
actionlint -version
# zhmakeindex 无参数运行时以非零码退出并打印用法，这里只确认它可执行。
zhmakeindex 2>&1 | head -n 1 || true
