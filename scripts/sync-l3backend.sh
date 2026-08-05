#!/usr/bin/env bash
# 用途: 修正 TeX Live 分发通道里 l3kernel 与 l3backend 的版本错配, 从 CTAN
# 取与 l3kernel 同日期的 l3backend 装进 TEXMFHOME.
#
# 临时措施 (#1048/#1050/#1051). 三处调用: _test-package.yml (regression),
# _check-doc-package.yml (l3build doc), release.yml (l3build ctan).
#
# ── 为什么需要 ────────────────────────────────────────────────────────
# tlnet 的 l3kernel (2026-07-20) 与 l3backend (2026-02-18) 差五个月.
# l3kernel 的 \__color_select_aux:nnN 调 \__color_backend_select_<model>:nN,
# 而旧 l3backend 只定义 :n 变体. \use:c 拿到未定义控制序列后展开成 \relax,
# 颜色参数掉进水平列表被当普通文字排版:
#   {gray}{0}          → 版面上出现 "gray 0"
#   {rgb}{1.0 0.0 0.0} → 版面上出现 "1.0 0.0"
# 只影响把所有颜色模型都 alias 到单个 \__color_backend_select:n 的后端
# (xetex, dvipdfmx); pdftex/luatex/dvips/dvisvgm 各模型独立定义, 不受影响.
#
# 两种可见症状, 对应两条 CI 路径:
#   - regression: \special{pdf:bc [...]} 从 .tlg 里消失, 变成
#     \TU/lmr/m/n/10 1.0 一类字符节点, 12 个测试变红 (见 d7457624).
#   - doc/ctan: 编译照样成功, 但 PDF 正文里散落 "0gray 0" 一类泄漏文本
#     (xeCJK.pdf 的 \meta 与 fntef 示例最明显). 没有任何退出码会变红,
#     所以这条路径必须靠本脚本预防, 事后无法从构建状态发现.
#
# ── 撤除条件 ──────────────────────────────────────────────────────────
# tlnet 的 l3backend 追上 l3kernel 后删掉本脚本及其三处调用. 判据是下面
# 打印的两个日期一致 —— 一致时本脚本即为空操作 (exit 0), 不影响结果,
# 所以留着不会坏事, 只是白占一步.
#
# 用法: scripts/sync-l3backend.sh
#   无参数. 依赖 kpsewhich / curl / unzip / tex 在 PATH 上.

set -euo pipefail

KERNEL_DATE=$(sed -n 's/.*\\def\\ExplFileDate{\([0-9-]*\)}.*/\1/p' \
  "$(kpsewhich expl3.sty)" | head -1)
# 用 pdftex 后端探测日期: 它在所有 TL 安装里都存在, 且与 xetex 后端同属
# l3backend 包, 版本必然一致. 探测用哪个 .def 与实际受影响的后端无关.
BACKEND_DATE=$(sed -n 's/.*{\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)}.*/\1/p' \
  "$(kpsewhich l3backend-pdftex.def)" | head -1)
echo "l3kernel:  $KERNEL_DATE"
echo "l3backend: $BACKEND_DATE"

if [ "$KERNEL_DATE" = "$BACKEND_DATE" ]; then
  echo "::notice::l3kernel 与 l3backend 日期一致, 无需 workaround; scripts/sync-l3backend.sh 及其调用可以删除了"
  exit 0
fi

echo "::warning::l3kernel ($KERNEL_DATE) 与 l3backend ($BACKEND_DATE) 日期不一致, 从 CTAN 取匹配版本"

WORK=$(mktemp -d)
# 逐个换 mirror 重试. mirrors.ctan.org 是自动重定向, 偶尔会落到证书链
# 不完整的镜像上 —— 实测 test-CJKpunct/ubuntu 与 PR #977 都报
# `curl: (60) SSL certificate problem: unable to get local issuer
# certificate`, 而同一 run 里其他 20 个 job 用同一份脚本全部成功,
# 所以是镜像侧的偶发问题, 不是脚本缺陷. 单点失败不该让整个 job 红,
# 因此换用固定 mirror 兜底.
#
# 不能只信 curl 的退出码. mirrors.ctan.org 是重定向服务, -L 跟到实际镜像
# 后若连接超时, --retry 耗尽仍可能返回 0 而 -o 只写出空/残缺文件 (实测
# doc-zhmetrics: 三次 `curl: (28) ... Timeout` 之后照样走进成功分支, 直到
# 末尾 kpsewhich 校验才拦下). 因此每个 mirror 下载后都验一次 zip 完整性,
# 用 unzip -t; 不合格就当作失败换下一个.
DOWNLOADED=
for url in \
  "https://mirrors.ctan.org/macros/latex/required/l3backend.zip" \
  "https://ctan.math.illinois.edu/macros/latex/required/l3backend.zip" \
  "https://mirror.ctan.org/macros/latex/required/l3backend.zip" ; do
  echo "尝试 $url"
  rm -f "$WORK/l3backend.zip"
  if curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 30 \
       --max-time 300 -o "$WORK/l3backend.zip" "$url" \
     && [ -s "$WORK/l3backend.zip" ] \
     && unzip -tq "$WORK/l3backend.zip" >/dev/null 2>&1 ; then
    DOWNLOADED=$url
    break
  fi
  echo "::warning::$url 下载失败或产物不是完整 zip, 换下一个 mirror"
done

if [ -z "$DOWNLOADED" ]; then
  echo "::error::所有 mirror 均无法下载 l3backend; 这是网络/镜像问题, 重跑本 job 即可"
  exit 1
fi
echo "下载自 $DOWNLOADED"

unzip -oq "$WORK/l3backend.zip" -d "$WORK"

# docstrip 的输出留在日志里. 之前这里重定向到 /dev/null, 配合下面 glob
# 未匹配时 cp 收到字面量的行为, 「zip 是空的」这类失败会一路静默到末尾
# 才被 kpsewhich 校验发现, 报出来的却是「注入未生效」, 掩盖真正的原因.
( cd "$WORK/l3backend" && tex l3backend.ins )

# 装进 TEXMFHOME 而不是各包的 localdir: kpse 优先于 texmf-dist 命中,
# 一步覆盖所有包和所有引擎, 且不往仓库工作树里落文件.
TEXMFHOME=$(kpsewhich -var-value TEXMFHOME)
DEST="$TEXMFHOME/tex/latex/l3backend"
mkdir -p "$DEST"

# nullglob + 显式计数: 未匹配时 bash 默认把 `l3backend-*.def` 字面量传给
# cp, 报错信息又容易被忽略. 这里让「解压出来一个 .def 都没有」立刻失败在
# 发生处, 而不是退化成末尾那句含义不同的「注入未生效」.
shopt -s nullglob
defs=( "$WORK/l3backend"/l3backend-*.def )
shopt -u nullglob
if [ "${#defs[@]}" -eq 0 ]; then
  echo "::error::解压/docstrip 后没有任何 l3backend-*.def; zip 可能不完整"
  exit 1
fi
echo "docstrip 产出 ${#defs[@]} 个 .def"
cp "${defs[@]}" "$DEST/"

# 必须刷新 ls-R, 否则刚拷进去的文件可能对 kpse 不可见.
#
# CI 上 setup-texlive-action 让 TEXMFHOME 解析到 texmf-local (实测 doc-ctex
# 的 resolved 路径就在 texmf-local 下), 而 texmf.cnf 的 TEXMFDBS 里
# TEXMFLOCAL 带 !! 前缀 —— 语义是"只查 ls-R, 绝不扫磁盘". 实测该树下磁盘上
# 真实存在的文件, 若无 ls-R 条目, kpsewhich 完全找不到.
#
# 其他 doc job 能成功, 靠的是 kpse "ls-R 比目录旧就回退扫盘"的宽容行为;
# zhmetrics 的 doc job 在本步骤之前跑了 `mktexlsr "$TEXMFHOME"` (为了让 kpse
# 认识它生成的 zhmCJK.tfm/map), 把 ls-R 刷成最新, 恰好关掉这个回退 —— 索引
# 是新的却不含随后拷进来的 .def, 于是解析回落到 texmf-dist 的 2026-02-18,
# 被下面的生效校验拦下. 所以偏偏是"刷过索引"的那个 job 挂掉.
#
# 无条件刷新 (而非仅在 ls-R 已存在时): TEXMFHOME 指向 !! 树时, 没有 ls-R
# 等于什么都找不到, 跳过刷新反而是错的.
mktexlsr "$TEXMFHOME" >/dev/null
echo "已刷新 $TEXMFHOME 的 ls-R"

# 生效判据: 经 kpse 解析到的必须是刚装的那份, 且日期与 l3kernel 一致.
# 少了这步核对, 「装错位置」与「装了但没生效」都会静默退化成原状.
RESOLVED=$(kpsewhich l3backend-pdftex.def)
NEW_DATE=$(sed -n 's/.*{\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)}.*/\1/p' \
  "$RESOLVED" | head -1)
echo "resolved:  $RESOLVED ($NEW_DATE)"
if [ "$NEW_DATE" != "$KERNEL_DATE" ]; then
  echo "::error::l3backend 注入未生效: 解析到 $RESOLVED ($NEW_DATE), 期望 $KERNEL_DATE"
  exit 1
fi
