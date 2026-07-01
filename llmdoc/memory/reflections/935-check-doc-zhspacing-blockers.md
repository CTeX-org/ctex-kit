# 反思：PR #935 check-doc.yml 与 zhspacing typeset 深层 blocker

## 任务

新增 `.github/workflows/check-doc.yml` 作为 PR 门禁，跑 `l3build doc` 补 `test.yml` 缺失的"文档 dtx→PDF 可编译性"维度。首轮 CI 暴露 3 个包 (xpinyin / zhmetrics / zhspacing) 从未在 CI 上被 typeset 过的隐蔽缺陷。**zhspacing 深挖后确认属于包本身 CI 改造范畴，超出 workflow layer 边界**，从 caller 里删除，留 followup。

## 关键设计决策

### 用 `l3build doc` 而非 `l3build ctan`

初版方案是 `l3build ctan`（跟 `release.yml` 同款）。dry-run 时发现 `l3build ctan` **内部硬编码**调 `call({"."}, "check")`（`l3build-ctan.lua:123`），整套 regression 会跑一遍，光 ctex 就 20+ min。但 `test.yml` 已经覆盖 check，这里 ctan 纯冗余。

`l3build doc` 是纯 typeset（`docinit + typesetpdf`，见 `l3build-typesetting.lua:183`），秒过 `typesetfiles={}` 的包（zhmetrics-uptex），精确对应"文档可编译性"这一 CI 缺口。牺牲 tdslocations 打包路径的验证——低频问题，打 release tag 时 `release.yml` 兜底就够，不放 PR 门禁。

### verify 脚本双重校验

`scripts/verify-doc-output.sh` 按 typesetfiles 逐 PDF 检查：
1. 文件存在
2. 前 4 字节 `%PDF` magic
3. **`>= 1024` 字节最小大小**——防 dvipdfmx fatal 后残留的 stub `%PDF` header（zhmetrics zhmCJK-test 场景实测：header 写完 15 字节后 fatal，其他 verify 逻辑通过但 pdf 无页面）

`typesetfiles={}` 的包 (`zhmetrics-uptex`) 期望零 PDF，`expected=()` 短路通过。

## 3 层 CI 修复（都在本 PR 内）

### xpinyin: TL opentype 未进 fontconfig

`xpinyin.dtx:179` `\newfontfamily\PinYinFont{TeX Gyre Adventor}` 走 fontconfig friendly name。TL 装了 `tex-gyre` 包，但字体只在 `$TEXMFDIST/fonts/opentype/public/tex-gyre/` 里，不在 fontconfig 索引 → xelatex 找不到。

修法：workflow 加 `/etc/fonts/conf.d/09-texlive-opentype.conf` 让 fc-cache 扫 TL `opentype/` + `truetype/` 目录。无条件执行，其他包只是索引多几百字体，无副作用。

### zhmetrics: TL 包不含顶层 tfm/map

TL `zhmetrics` 包只装 `fonts/tfm/zhmetrics/{gbk,unicode*}/` 分片 tfm，**不含**顶层 `zhmCJK.tfm` / `zhmCJK.map`（顶层 tfm + fontname map）。这两个是 `zhmCJK.lua map` 在 `copyctan_posthook`（`zhmetrics/build.lua:28-49`）里生成后**CTAN admin 上传独立文件**——TL 打包时不知何故没进 zhmetrics 包。

`zhmCJK.dtx` typeset 时请求 `zhm35b` 走 fontname map 失败，mktextfm fallback 试 metafont 也失败（zhm35b.mf 不存在）。

修法：workflow 加 `pkg==zhmetrics` pre-doc step，用包内 `zhmCJK.lua` 生成 tfm/map，装到 `TEXMFHOME` (`$HOME/texmf/fonts/tfm/zhmcjk/` + `.../fonts/map/fontname/`) 并 texhash。`.github/tl_packages` 补 `fontware`（提供 `pltotf`，`zhmCJK.lua` 用它做 pl→tfm 转换）。build.lua 不变。

**zhmCJK-test.pdf 从 verify expected 移除**：`zhmCJK-test.tex` 硬编码 `simsun.ttc/simhei.ttf` **文件名**（fontspec `[filename]` 语法走 kpse 查文件，fontconfig alias 救不了），CI 无这两个字体，dvipdfmx 中止。test.tex 是包内部字体安装 demo，与文档 CI 目标无关。

### zhspacing: 深层 blocker，从 caller 删除

**依赖不止是商业字体**。首层：`zhfont.sty` 硬编码 `SimSun/SimHei/KaiTi/FangSong/Sun-Ext*` (`zhfont.sty:62-68`)，`zhmath.sty` 有 `Times New Roman`，`zhs-man.tex` executable 位置也用同款。

尝试用 fontconfig alias / `<match target=pattern>` 均无效——**XeTeX/fontspec 内部字体查找路径不完全走 fontconfig**：本地实测 `fc-match SimSun → Noto Serif CJK SC` 生效，但 `xelatex \newfontfamily{SimSun}` 依然 "cannot be found"。fontconfig alias 救不了 fontspec。

改用**workspace 内 sed 就地 patch**（`zhfont.sty` / `zhmath.sty` / `zhspacing.sty` / `zhs-man.tex`）替换字体名为 Noto CJK / TeX Gyre Termes。层层剥出：
- 表层 SimSun/SimHei friendly name → 换成 Noto
- `[simfang.ttf]` file-name 语法 → 换成 Noto friendly name（`[file]→{Noto}` 会因外层 macro 参数 `{#2}` 变成双大括号 `{{Noto}}` 报错，改为无 `{}` 的替换）
- Times New Roman → TeX Gyre Termes（TL 已装，进 fontconfig 后可用）
- `\zhcjkextafont` `\newfontfamily` → `\renewfontfamily`（zhspacing.sty line 578 `\@ifundefined` fallback 已 `\def` 定义过）

改完前 3 层后暴露**第 4 层**（`zhspacing.sty` 自身 bug）：
```
! Undefined control sequence.
<argument> \@nil
l.17 \zhspacing
...
! File ended while scanning use of \@iforloop.
```

`\@iforloop` 定义在 `zhsusefulmacros.sty:22`，加载成功但 `\zhspacing` 命令展开时找不到 `\@nil` / `\@iforloop`。之前之所以从未暴露，是**因为更早的 `SimSun cannot be found` 让 nonstopmode 早退**——我把字体错修好让编译走得更远，反而挖出下一层缺陷。

**决策**：zhspacing 从 caller 里删除。上一次 tag 是 `zhspacing-20160514`（2016 年），10 年未维护；`release.yml` 也从未真正验证过它的 typeset 链路。要修好意味着改 `zhspacing.sty` / `zhfont.sty` 内部（catcode/`@` letter 时序、命令定义顺序），是**包本身 CI 改造**，不合适塞进"新增 workflow 门禁"这类 infra PR。留 followup issue。

## 教训

### 修 CI 时禁忌用 nonstopmode 错误结论

zhspacing 前 3 层修复都是"改一步暴露下一层"的连锁。**nonstopmode 会让 fontspec/其他 fatal 之后 TeX 继续跑但状态混乱，产生 `\@iforloop` 之类的 undefined 假象**——错误链条不能一步一步展开时，回头审视上一层是否真的是根因。如果 zhspacing 从一开始就跑 `-halt-on-error` 应能直接看到 fontspec error 而非到后期的 `\@iforloop`。

### fontconfig alias 不能救 XeTeX/fontspec

多轮尝试证明：
- `<alias binding=strong>` — 只影响 `fc-match` 单查询
- `<match target=scan><edit family prepend>` — 影响 `fc-list :family=SimSun` 但 xelatex/fontspec 依然找不到
- `<match target=pattern>` — 同上

xelatex/fontspec 通过 xetex 内置字体查找 API（含 fontconfig 但也含 kpse + `\newfontfamily` 自己的解析），alias 层无法拦截。**给 CI 上"不存在的商业字体"提供替代的唯一稳定办法：patch dtx / sty 里的字体名**（就地 sed 或改上游）。

### `l3build ctan` 内部会跑 check

**不能把 `l3build ctan` 当"轻量打包"用**。它硬编码调 check，用于 CI 门禁必然引入完整 regression 成本。若目标是"文档编译"，应该用 `l3build doc`；若目标是"打包链路可达性"，才用 `l3build ctan`（且必须接受 check 时长）。

### TL 里的包不一定含 upstream 项目产物

zhmetrics 教训：**CTAN 上的包和 TL 里的包不必等价**。TL 包由 TL 维护者从 CTAN 拉取重打包，可能省略某些"下游生成物"（如 zhmetrics 的顶层 tfm/map 是 CTAN admin 手工上传独立文件，TL 打包时未纳入）。CI 上要 typeset 依赖这些的 dtx，就必须在 pre-doc 阶段用包自己的脚本重新生成一遍装到 TEXMFHOME。

### 修完新 CI 首轮暴露的错误应当就地修，不留尾巴

首轮 CI 3 包挂：xpinyin / zhmetrics 都能在 workflow 层就地解决（+ 补 tl_packages），单独开 followup issue 反而稀释了 PR 的完整性。zhspacing 在剥了 3 层还能看到下一层时果断放弃，比强行修完让 PR diff 膨胀更明智——**PR 的"完整"定义应该是"能 merge 后守住不再回归"，而非"覆盖 100% 的包"**。

## 促进候选

- **升级到 `guides/`**：写一份"给 CI 添加新的 typeset 门禁"的 how-to，把上面 4 层踩坑（先 typeset 缺什么字体 → 装 TL 包 → 补 fontconfig 索引 / TEXMFHOME → patch dtx / sty 字体名）作为流程。**暂缓**：目前只有一次新增门禁的经验，模式还不算 recurring。等到未来有第二次 typeset-only CI 门禁需求时再促进。
- **升级到 `reference/build-and-test.md`**：check-doc.yml 的 CI 结构应加进 CI/CD 章节（本次已做）。
- **升级到 `must/`**：不适合——这些都是"新增门禁 workflow"路径下的细节，非日常开发必读。

## 相关

- 决策：`llmdoc/memory/decisions/935-check-doc-vs-ctan.md`（本次同步创建，记录 doc vs ctan 的取舍）
- 反思：`llmdoc/memory/reflections/874-876-agentic-fork-shielding-cron.md`（同为 CI workflow 层面的稳定约束）
- Stable：`llmdoc/reference/build-and-test.md` CI/CD 章节
