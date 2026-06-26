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
# 另: hooks / check-pr-ci 是 git workflow 入口, build-gbk2uni 走子 Makefile.

L3BUILD_PKGS := xeCJK ctex CJKpunct xCJK2uni xpinyin zhlineskip \
                zhmetrics zhmetrics-uptex zhnumber zhspacing jiazhu

VERBS := doc unpack ctan check clean

.PHONY: help hooks check-pr-ci check-ctex-serial \
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

# ── git workflow ───────────────────────────────────────────────────────────
hooks:                       ## 一次性安装 git hooks
	git config core.hooksPath .githooks
	@echo "hooks installed: $$(git config core.hooksPath)"

check-pr-ci:                 ## 手动触发 PR CI watch + review 抓取(同 pre-push self-wrapper 调用的)
	./.githooks/check-pr-ci.sh

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
