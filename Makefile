# Makefile —— 本地任务入口. 详细 hook 说明见 .githooks/README.md.
#
# 命名约定:
#   make <verb>          = <verb>-all 的别名(跑全部包)
#   make <verb>-all      = 跑全部包(显式)
#   make <verb>-<pkg>    = 只跑指定包(例如 make check-xeCJK)
#
# 涉及 verb: doc / unpack / ctan / check / clean
#   doc    —— l3build doc:生成 PDF 文档
#   unpack —— l3build unpack:解包 .dtx 得到 .sty/.cls/.cfg 等运行时文件
#   ctan   —— l3build ctan:打 ctan 发布包(含 doc + tds.zip)
#   check  —— l3build check:跑回归测试(ctex 经 check-ctex 4-engine 并行 ~8min,
#             串行旧法 ~20min;小包通常几十秒)
#   clean  —— l3build clean
#
# Release 流程:
#   make tag <pkg>-v<ver>      —— 本地打 tag, 不 push. push 需手动 git push origin <tag>
#                                 (push 后由 .github/workflows/release.yml 自动跑 ctan 打包 + GH Release)
#
# 另: hooks / check-pr-ci 是 git workflow 入口, build-gbk2uni 走子 Makefile.

L3BUILD_PKGS := xeCJK ctex CJKpunct xCJK2uni xpinyin zhlineskip \
                zhmetrics zhmetrics-uptex zhnumber zhspacing jiazhu

VERBS := doc unpack ctan check clean

.PHONY: help hooks check-pr-ci check-ctex-serial tag \
        $(VERBS) \
        $(foreach v,$(VERBS),$(v)-all) \
        $(foreach v,$(VERBS),$(addprefix $(v)-,$(L3BUILD_PKGS))) \
        doc-gbk2uni unpack-gbk2uni clean-gbk2uni

# ── 默认 target: 列出可用 target ────────────────────────────────────────────
help:                       ## 显示此帮助
	@echo "ctex-kit Makefile —— 本地任务入口"
	@echo ""
	@echo "  L3BUILD_PKGS = $(L3BUILD_PKGS) (+ gbk2uni via sub-Makefile)"
	@echo ""
	@echo "Build/test verbs (per-pkg or -all):"
	@for v in $(VERBS); do \
	  printf "  make %-22s\n" "$$v"; \
	  printf "  make %-22s\n" "$$v-all"; \
	  printf "  make %-22s\n" "$$v-<pkg>"; \
	done
	@echo ""
	@echo "Examples:"
	@echo "  make unpack-xeCJK         # 只解包 xeCJK"
	@echo "  make check-xeCJK          # 只跑 xeCJK 的 l3build check"
	@echo "  make doc                  # 全包 l3build doc"
	@echo "  make ctan-ctex            # 打包 ctex 到 ctan 格式"
	@echo ""
	@echo "Git workflow:"
	@echo "  make hooks                # 一次性安装 git hooks (.githooks)"
	@echo "  make check-pr-ci          # 手动触发 PR CI watch + review 抓取"
	@echo ""
	@echo "Release:"
	@echo "  make tag <pkg>-v<ver>     # 本地打 release tag, 不 push (e.g. make tag xeCJK-v3.10.1-rc2)"

# ── git workflow ───────────────────────────────────────────────────────────
hooks:                       ## 一次性安装 git hooks
	git config core.hooksPath .githooks
	@echo "hooks installed: $$(git config core.hooksPath)"

check-pr-ci:                 ## 手动触发 PR CI watch + review 抓取(同 pre-push self-wrapper 调用的)
	./.githooks/check-pr-ci.sh

# ── tag (release) ──────────────────────────────────────────────────────────
# 用法: make tag <pkg>-v<X>.<Y>.<Z>[-rc<N>]   (e.g. make tag xeCJK-v3.10.1-rc2)
#
# 合法 tag 格式 (严格校验, 不向后兼容历史不规范 tag):
#   <pkg>-v<X>.<Y>.<Z>           例如  xeCJK-v3.10.1
#   <pkg>-v<X>.<Y>.<Z>-rc<N>     例如  xeCJK-v3.10.1-rc2
# <pkg> 必须是 L3BUILD_PKGS 之一 (与 release.yml tags trigger 对齐).
# 三段语义化版本 (semver-lite), 可选 rc<N> 后缀. 其他形式 (2 段 / letter 后缀 /
# alpha / beta / pre / date 串 / 缺 v 前缀等) 一律拒绝, 避免误打.
#
# 历史 tag (ctex-1.02c / xpinyin-v2.2 / zhmetrics-uptex-v1.0 / zhlineskip-v1.0f
# / zhspacing-20160514) 与此规则不一致, 但只影响后续新打 tag, 不影响已存在
# release 的可读性.
#
# 打本地 annotated tag, 不 push. push 需手动 git push origin <tag> —— 这是
# 故意设计, 让操作者在 push 前可以最后核对 tag 是否落在期望 commit、是否
# 还有未提交的版本号 / \changes 改动. push 之后 release.yml 自动跑.
#
# 实现: tag target 把第二个 MAKECMDGOALS 当 tag 名, 用 noop phony rule
# 吃掉它避免 "No rule to make target xeCJK-v..." 报错.

# 校验用的 pkg 列表 (与 release.yml tags trigger 对齐). 用 | 拼接成 regex
# alternation, 注意 zhmetrics-uptex 必须排在 zhmetrics 前面, 否则 regex
# 贪婪匹配会先吃掉 zhmetrics.
TAG_PKGS_REGEX := ctex|xeCJK|CJKpunct|xCJK2uni|xpinyin|zhlineskip|zhmetrics-uptex|zhmetrics|zhnumber|zhspacing

TAG_NAME := $(filter-out tag,$(MAKECMDGOALS))

tag:                         ## 本地打 release tag (用法: make tag <pkg>-v<X>.<Y>.<Z>[-rc<N>])
	@if [ -z "$(TAG_NAME)" ]; then \
	  echo "用法: make tag <pkg>-v<X>.<Y>.<Z>[-rc<N>]" >&2; \
	  echo "  例如: make tag xeCJK-v3.10.1" >&2; \
	  echo "        make tag xeCJK-v3.10.1-rc2" >&2; \
	  exit 1; \
	fi
	@if ! printf '%s' "$(TAG_NAME)" \
	  | grep -qE '^($(TAG_PKGS_REGEX))-v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$$'; then \
	  echo "✗ tag 名 '$(TAG_NAME)' 不是合法 release tag" >&2; \
	  echo "  合法格式: <pkg>-v<X>.<Y>.<Z>[-rc<N>]" >&2; \
	  echo "  支持的 pkg: $(TAG_PKGS_REGEX)" >&2; \
	  echo "  例如:     xeCJK-v3.10.1 / xeCJK-v3.10.1-rc2" >&2; \
	  exit 1; \
	fi
	@if git rev-parse -q --verify "refs/tags/$(TAG_NAME)" >/dev/null 2>&1; then \
	  echo "✗ tag '$(TAG_NAME)' 已存在本地. 先删: git tag -d $(TAG_NAME)" >&2; \
	  exit 1; \
	fi
	git tag -a "$(TAG_NAME)" -m "$(TAG_NAME)"
	@echo ""
	@echo "✓ tag '$(TAG_NAME)' 已打在 $$(git rev-parse --short HEAD) ($$(git log -1 --format=%s | head -c 60))"
	@echo ""
	@echo "下一步 push 触发 release.yml (会自动 ctan 打包 + 上传 GH Release prerelease):"
	@echo ""
	@echo "    git push origin $(TAG_NAME)"
	@echo ""
	@echo "如果发现要重打:"
	@echo "    git tag -d $(TAG_NAME)"
	@echo ""

# 让 MAKECMDGOALS 第二个 arg 不报 "No rule to make target".
# 只在 tag 是当前 goal 且确实给了 tag 名时, 把 tag 名声明为 phony noop.
# 这比通配 `%:` rule 安全, 不会触发 "overriding recipe for target ..." 警告.
ifneq ($(filter tag,$(MAKECMDGOALS)),)
ifneq ($(TAG_NAME),)
.PHONY: $(TAG_NAME)
$(TAG_NAME):
	@:
endif
endif

# ── 显式 -all 别名 (e.g. `make doc` = `make doc-all`) ──────────────────────
$(VERBS): %: %-all

# ── 通用 -all: 遍历全部 l3build 包 + gbk2uni 适用项 ────────────────────────
doc-all: $(addprefix doc-,$(L3BUILD_PKGS)) doc-gbk2uni
unpack-all: $(addprefix unpack-,$(L3BUILD_PKGS)) unpack-gbk2uni
ctan-all: $(addprefix ctan-,$(L3BUILD_PKGS))
check-all: $(addprefix check-,$(L3BUILD_PKGS))
clean-all: $(addprefix clean-,$(L3BUILD_PKGS)) clean-gbk2uni

# ── 单包 target: $(verb)-$(pkg) → cd $(pkg) && l3build $(verb) ─────────────
# 用 pattern rule 写法, 一条规则覆盖全部 verb × pkg 笛卡儿积.
#
# 注: check 的 ctex / xeCJK 等"大包"的 pattern 规则会被下方的 per-pkg
# override (check-ctex 走 scripts/check-parallel.sh 多 engine 并行).
# 其他小包仍走默认串行规则.
define L3BUILD_PKG_RULES
$(addprefix doc-,    $(1)): doc-%:    ; cd $$* && l3build doc
$(addprefix unpack-, $(1)): unpack-%: ; cd $$* && l3build unpack
$(addprefix ctan-,   $(1)): ctan-%:   ; cd $$* && l3build ctan
$(addprefix check-,  $(1)): check-%:  ; cd $$* && l3build check
$(addprefix clean-,  $(1)): clean-%:  ; cd $$* && l3build clean
endef
$(eval $(call L3BUILD_PKG_RULES,$(L3BUILD_PKGS)))

# ── check 大包并行加速 (override 上方 pattern rule) ────────────────────────
# ctex 默认跑 4 engine, 串行 ~20min wall-clock; 并行后 ~8min. 走
# scripts/check-parallel.sh, 给每个 engine 准备一份独立子工作目录
# (tmp/parallel-check/<engine>/, git ls-files + tar 快照), 各 engine 进程在
# 自己的目录下跑 l3build check, 互不争抢. 同步 ctex 主测 + 各 -c config 三个
# (cmap / contrib / ctxdoc) 都跑.
check-ctex:                  ## ctex 4-engine 并行 l3build check (~8min)
	cd ctex && CONFIGS="test/config-cmap test/config-contrib test/config-ctxdoc" \
	  ../scripts/check-parallel.sh

check-ctex-serial:           ## ctex 串行 l3build check (~20min, 用于调试并行)
	cd ctex && l3build check
	cd ctex && l3build check -c test/config-cmap
	cd ctex && l3build check -c test/config-contrib
	cd ctex && l3build check -c test/config-ctxdoc

# ── gbk2uni 走子 Makefile ──────────────────────────────────────────────────
doc-gbk2uni unpack-gbk2uni:
	$(MAKE) -C gbk2uni

clean-gbk2uni:
	-$(MAKE) -C gbk2uni clean 2>/dev/null || true
