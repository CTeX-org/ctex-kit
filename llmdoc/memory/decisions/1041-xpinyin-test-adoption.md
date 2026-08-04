# 决策：为 xpinyin 建立独立回归测试并接入版本校验（#1041 后续）

## 背景

xpinyin 已接入按 tag 构建发布包的自动化流程，但此前没有任何独立回归测试——唯一的验证是 `check-doc.yml` 里 `l3build doc` 编得过手册，那只能说明 PDF 能生成，不能说明注音行为正确。本次补上测试目录并接入各条 workflow；**宏包代码本身未改动**。

## 决策：两条互不复用的适配路线必须分别测试，且必须分目录

xpinyin 用 `bool_lazy_or:nnF { xetex } { pdftex }` 把 luatex 挡在 `\msg_critical:nn` 上（实测 lualatex 直接以 "Engine `luatex' is not yet supported" 中止），所以只有 xetex 与 pdftex 两条路线——而两条都必须测：包内 `\@@_adjust_xeCJK_hook:` 与 `\@@_adjust_CJK_hook:` 是两套互不复用的适配（字体选择、码位转换、接管 `\CJKsymbol` 的方式都不同），只测 xetex 会让 CJKutf8 那一半零覆盖。

两条路线不能共用一个 `testfiledir`：`l3build check` 把目录下每个 `.lvt` 都拿去跑 `checkengines` 里的每一个引擎，没有按文件指定引擎的机制，混在一起会互相拿对方的引擎跑并因缺基线报错。因此 pdfTeX 那条线放进 `xpinyin/test/config-cjk.lua` + `xpinyin/testfiles-cjk/`，仿 `ctex/test/config-cmap.lua` 等既有专项配置的做法。`config-cjk.lua` 把 `checkdeps` 显式清空——CJKutf8 路线不加载 xeCJK，不需要复制它的产物。

否决方案：把两条路线的用例混进同一 `testfiles/`，靠文件名约定分流。这做不到——`l3build check` 没有按文件指定引擎的机制，混合目录下任何一条路线的用例都会被拿去跑另一条路线的引擎并因缺基线报错，这不是命名约定能规避的结构性限制。

## 决策：四个测试文件按观察通道分工，而非按功能模块分工

- `pinyin-tone01.lvt`（31 格）：声调数字到重音命令的映射，oracle 取直接写重音命令的字面形式，比宽高深三个维度——间接证据，判别力依赖字体是否恰好给出不同尺寸。
- `pinyin-tone02.lvt`：用 `\loggingoutput` 固定 shipout 的实际字形——正面证据，与字体度量是否巧合无关。
- `pinyin-scope01.lvt`：注音的开关与作用域，同样用 `\loggingoutput` 固定节点列表——这一类断言（哪些字被注了音、注的是什么）不能用盒子尺寸观察。
- `pinyin-setup01.lvt`：`\xpinyinsetup` 各键的可观察效果，用「改前 vs 改后」的差值而非绝对值。
- `pinyin-cjkutf8-01.lvt`：CJKutf8/pdfTeX 路线，覆盖前两类断言的等价内容。

按观察通道分工是因为同一个功能维度（例如「读音是否正确」）需要不同的证据形式才能获得判别力：尺寸比较拦不住字体恰好同尺寸的情况，节点列表才是正面证据。见下方「四条判别力教训」。

## 决策：四条判别力教训——均以「重新引入缺陷、确认它会变红」实测确认

1. **oracle 必须显式切到候选同一字体族**，否则全部单元恒报 DIFF（比的是两种字体的度量差，不是数字到重音的映射）。初版漏了这一步，全部 29 格都报 DIFF。
2. **拼音字体缺字时会假通过**。文档默认的 Latin Modern 缺 U+01D6（ǖ）；候选与 oracle 同时缺同一个字符，尺寸仍相等，看着通过、实际什么都没验证。改用 `DejaVuSerif.ttf` 后实测零 "Missing character"。
3. **只测带声调数字的 v 会漏掉 `\@@_replace_v:n`**。v 到 ü 的转换由两个各自判断 l/n 的函数分担；只写带数字的用例不够——实测把 `\@@_replace_v:n` 的 l/n 守卫整段删掉，前四组仍全绿。需要「前面有数字音节、末音节不带数字」的写法才能触发这条路径。
4. **`\xpinyin{长}{zhang3}` 要的正是数据库首选值，没有判别力**。必须挑非首选读音（cháng）才构成真正的对照。

## 决策：两条结构性事实必须写进测试注释

- **注音汉字的宽度看不出拼音内容**：拼音在 `\hbox_overlap_right:n` 这个零宽盒里，换读音乃至整段关掉注音，整盒宽度都不变（实测 chang2/zhang3 同为 10pt）。内容类断言一律交给节点列表。
- **CJK 环境必须开在盒子内部**：`\begin{CJK}` 包住 `\hbox_set:Nn` 时汉字进不了盒子，三项宽高全为 0pt，而 0pt = 0pt 让「宽度不变」照样报 unchanged。

## 决策：观察手段选 `\loggingoutput`，不用 `\showbox`／`\box_log:N`

三者都会抛 `! OK.`；xpinyin 的 `checkopts` 带 `-halt-on-error`，会当场终止编译，其后用例静默不执行而 `check` 仍可能报绿。这个坑在 xeCJK 的 `verb-ecglue02.lvt`／`fntef-shrink01.lvt` 注释里也记着，属于跨包可复用的教训。

## 决策：`checkdeps` 必须配 `checkinit_hook`

`xpinyin/build.lua` 的 `checkdeps = {"../xeCJK"}` 只保证依赖包先被 `unpack`，产物留在依赖包自己的 `build/unpacked/` 里，kpse 搜不到——`\usepackage{xeCJK}` 仍会命中系统 TeX Live 的版本。实测不加 `checkinit_hook` 时，测试日志里的路径是 `texmf-dist/tex/xelatex/xecjk/xeCJK.sty`，测的其实是本机装了什么，跨机器不可复现。修法与 `ctex/build.lua` 一致：`checkinit_hook` 手工把依赖包 `installfiles` 复制进本包的测试目录。

## 决策：xpinyin 接入版本管理双闸校验，沿用 xeCJK 的共享 `update_tag` 路线

`xpinyin/build.lua` 新增 `version` 字段作事实源；共享 `update_tag`（`support/build-config.lua`）已支持 `xpinyin.dtx` 的两处版本写法（`\ProvidesExplPackage` 的 `{\ExplFileDate}{<ver>}` 与 `xpinyin-database.def` 的 `\ProvidesFile` `[<日期> v<ver> xpinyin database]`），无需改 Lua——实测 `l3build tag` 为 no-op。

`check-tag.yml` 新增 `tag-xpinyin` job；`release.yml` 补 `xpinyin)` case，校验 git tag / build.lua / **两处** dtx 版本一致。此前它走 `*)` 静默跳过，正是 #1041（xeCJK 版本闸）记录的白名单默认放行模式在 xpinyin 上的复现。两种失败模式（只 bump build.lua；两处只同步其一）都已实测能拦住。详见 [[1041-xecjk-version-gate]]。

## CI 接入细节

- `test.yml`：新增 `test-xpinyin` caller，paths filter 含 `xeCJK/**`（XeTeX 路线以工作树的 xeCJK 为运行时依赖），并入 `test-result` 汇总。
- `_test-package.yml`：新增 `needs-unihan` 输入（unpack 阶段跑 `texlua xpinyin.lua` 生成拼音数据库，数据源是 unicode.org 的 Unihan.zip），weekly cache key 与 `_check-doc-package.yml` 完全一致，两边互相填缓存；非 ctex 分支支持逐个跑额外 config（`configs` 输入）。
- `Makefile`：`CHANGELOG_PKGS` 加入 xpinyin（随本次补写首条 `\changes{v3.2}{...}`）。
- `.github/tl_packages`：加 `dejavu`、`gnu-freefont`（测试用字体，已核对是这两个包提供）。

## 相关

- 前身：[[1041-xecjk-version-gate]]（白名单默认放行模式、共享 `update_tag` 的前两个坑）
- Stable：`llmdoc/reference/build-and-test.md` 「xpinyin 的注音回归（#1041）」一节与「版本管理」覆盖矩阵
- 实现：`xpinyin/build.lua`、`xpinyin/test/config-cjk.lua`、`xpinyin/testfiles/`、`xpinyin/testfiles-cjk/`、`support/build-config.lua`、`.github/workflows/{test,_test-package,check-tag,release}.yml`、`Makefile`、`.github/tl_packages`
