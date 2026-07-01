# 决策：#935 PR 门禁用 `l3build doc` 而非 `l3build ctan`

## 决策

新增 `.github/workflows/check-doc.yml`（PR 门禁），执行 `l3build doc` 而非 `l3build ctan`。牺牲 tdslocations 打包路径验证，换 CI 时长与语义精准度。

## 背景

`test.yml` 只跑 `l3build check`（regression），完全不 typeset dtx → PDF。文档编译链路只在 push tag 触发 `release.yml` 时才被验证（`release.yml` 里 `l3build ctan` 内部会 typeset），炸了要等打 tag 才发现。

初版方案是让新 PR 门禁跑 `l3build ctan`——与 release.yml 对齐、顺带覆盖 tds 打包。dry-run 发现问题。

## 关键约束

`l3build ctan` 内部**硬编码**调 `call({"."}, "check")`（见 `l3build-ctan.lua:123`），整套 regression 会跑一遍。ctex 单包实测 20+ min，跟 `test.yml` 相当——**在 PR 门禁场景是完全冗余的重复工作**。

`l3build doc` 是纯 typeset（`docinit + typesetpdf`，见 `l3build-typesetting.lua:183`）：
- 不 check
- 不 install/tds 打包
- `typesetfiles={}` 的包（zhmetrics-uptex）秒过

## 分工

| Workflow | Target | 覆盖 |
|---|---|---|
| `test.yml` | `l3build check` | 5 主包 × 4 engine × 数百 regression |
| `check-doc.yml` | `l3build doc` | 9 全包 × 1 engine，只 typeset dtx → PDF |
| `release.yml` | `l3build ctan` | 打 tag 触发；`ctan` 内含 check + typeset + tds packing |

三者组合覆盖：
- **PR 阶段**：`test.yml` 抓 regression + `check-doc.yml` 抓文档编译回归
- **Release 阶段**：`release.yml` 兜底 tdslocations 打包路径可达性（低频，非门禁）

## 牺牲的维度

`l3build doc` 不覆盖：
- **tds tree 布局**：`tdslocations` 里的路径漏配、`installfiles` 与 `sourcefiles` 不一致等 CTAN 打包问题
- **`copyctan_posthook`** 里的自定义 zip 装配逻辑

这类问题在 `release.yml` 打 tag 时才会真正暴露。可接受——tag 频率低，打包错误可以在 release 前通过 `make ctan-<pkg>` 本地演练发现。**PR 门禁不需要覆盖这一层**。

## 附带发现（首轮 CI 暴露）

以下 3 包 typeset 缺陷从未在 CI 上被检测过（`test.yml` 不 typeset），首次跑 `check-doc.yml` 才暴露：

- **xpinyin**：`\newfontfamily{TeX Gyre Adventor}` 需 fontconfig friendly name，TL 装了但字体不在 fontconfig 索引 → workflow 加 fc-cache 扫 TL opentype 目录
- **zhmetrics**：TL zhmetrics 包不含顶层 `zhmCJK.tfm`/`.map` → workflow 加 pre-doc step 用 `zhmCJK.lua` 生成装到 TEXMFHOME
- **zhspacing**：多层依赖 + `zhspacing.sty` 自身 `\@iforloop`/`\@nil` 时序 bug → 从 caller 里删除，followup issue

详见 [[935-check-doc-zhspacing-blockers]]。

## 相关

- 反思：[[935-check-doc-zhspacing-blockers]]
- Stable：`llmdoc/reference/build-and-test.md` CI/CD 章节
- PR：#935
