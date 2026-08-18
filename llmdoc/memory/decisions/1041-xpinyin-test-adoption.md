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
- `pinyin-scope01.lvt`：注音的开关与作用域，同样用 `\loggingoutput` 固定节点列表——这一类断言（哪些字被注了音、注的是什么）不能用盒子尺寸观察。改格式而不改尺寸的 `multiple`、`format` 着色、`footnote` 三项也归这里。
- `pinyin-setup01.lvt`：`\xpinyinsetup` 中**能用尺寸观察的六个键**（`ratio`／`vsep`／`hsep`／`pysep`／`font`／`format`），用「改前 vs 改后」的差值而非绝对值。其中 `format` 在这里只固定「加了它尺寸不变」这一半，着色本身归 `scope01`。
- `pinyin-cjkutf8-01.lvt`：CJKutf8/pdfTeX 路线，覆盖前两类断言的等价内容。

上面这份清单是 #1041 落地时的状态。#997 之后 `testfiles/` 又追加了 `pinyin-fallback01.lvt`
（观察通道是 `\loggingoutput` 下量宽盒子**自身**的宽度，见 [[997-xpinyin-fallback-reselect]]），
因此「四个」只对本决策所述的那个时点成立；当前清单以
`llmdoc/reference/build-and-test.md` 的「xpinyin 的注音回归（#1041）」一节为准，那里不再冻结总数。

按观察通道分工是因为同一个功能维度（例如「读音是否正确」）需要不同的证据形式才能获得判别力：尺寸比较拦不住字体恰好同尺寸的情况，节点列表才是正面证据。见下方「四条判别力教训」。

这条分工原则曾被违反两次，且是同一个模式的两次发作，值得记下。

第一次：`multiple` 键最初只出现在 `pinyin-setup01.lvt` 的覆盖清单里，并由 `pinyin-scope01.lvt` 用「格式见 pinyin-setup01」交叉引用指向它，而两个文件都没有它的用例。盲审据此提出重要问题——按注释判断的人会以为该键有回归保护。

第二次：补上 `multiple` 之后，`setup01` 里仍留着一条指向 `pinyin-setup02` 的注释，而那个文件从未存在；`format` 键的着色路径（`\l_@@_format_tl`）也因此实际零覆盖——`setup01` 只断言「加了 format 尺寸不变」，`scope01` 覆盖的是只管多音字的 `multiple`，两者都不管作用于全部拼音的 `format` 着色。终审盲审查出这条悬空引用。

两次的根因相同：改颜色的键放进了以宽高比较为手段的文件。**当一份测试的「覆盖清单」与它实际的观察手段不匹配时，缺的往往不是一个用例，而是它被放错了文件。** 相应地，**指向另一个文件的交叉引用必须逐条验证目标真实存在**——悬空引用比没有引用更有害，它会让维护者以为某处有校验。修正后 `multiple`（红）与 `format`（蓝）在 `scope01` 互为对照，两者都必需：只有前者时，把二者作用范围搞混不会被任何用例发现。

## 决策：四条判别力教训——均以「重新引入缺陷、确认它会变红」实测确认

1. **oracle 必须显式切到候选同一字体族**，否则全部单元恒报 DIFF（比的是两种字体的度量差，不是数字到重音的映射）。初版漏了这一步，当时的全部 24 格都报 DIFF。
2. **拼音字体缺字时会假通过**。文档默认的 Latin Modern 缺 U+01D6（ǖ）；候选与 oracle 同时缺同一个字符，尺寸仍相等，看着通过、实际什么都没验证。改用 `DejaVuSerif.ttf` 后实测零 "Missing character"。
3. **只测带声调数字的 v 会漏掉 `\@@_replace_v:n`**。v 到 ü 的转换由两个各自判断 l/n 的函数分担；只写带数字的用例不够——实测把 `\@@_replace_v:n` 的 l/n 守卫整段删掉，前四组仍全绿。需要「前面有数字音节、末音节不带数字」的写法才能触发这条路径。
4. **`\xpinyin{长}{zhang3}` 要的正是数据库首选值，没有判别力**。必须挑非首选读音（cháng）才构成真正的对照。

## 决策：两条结构性事实必须写进测试注释

- **注音汉字的宽度看不出拼音内容**：拼音在 `\hbox_overlap_right:n` 这个零宽盒里，换读音乃至整段关掉注音，整盒宽度都不变（实测 chang2/zhang3 同为 10pt）。内容类断言一律交给节点列表。
- **CJK 环境必须开在盒子内部**：`\begin{CJK}` 包住 `\hbox_set:Nn` 时，出环境后三项宽高全为 0pt，而 0pt = 0pt 让「宽度不变」照样报 unchanged。成因是 `\hbox_set:Nn` 的局部赋值被环境分组还原成 void（环境内读它是 12.75551pt，`\hbox_gset:Nn` 则环境外也可读），不是汉字排不进盒子。

## 决策：观察手段选 `\loggingoutput`，不用 `\showbox`／`\box_log:N`

三者都会抛 `! OK.`；xpinyin 的 `checkopts` 带 `-halt-on-error`，会当场终止编译，其后用例静默不执行而 `check` 仍可能报绿。这个坑在 xeCJK 的 `verb-ecglue02.lvt`／`fntef-shrink01.lvt` 注释里也记着，属于跨包可复用的教训。

## 决策：`checkdeps` 必须配 `checkinit_hook`

`xpinyin/build.lua` 的 `checkdeps = {"../xeCJK"}` 只保证依赖包先被 `unpack`，产物留在依赖包自己的 `build/unpacked/` 里，kpse 搜不到——`\usepackage{xeCJK}` 仍会命中系统 TeX Live 的版本。实测不加 `checkinit_hook` 时，测试日志里的路径是 `texmf-dist/tex/xelatex/xecjk/xeCJK.sty`，测的其实是本机装了什么，跨机器不可复现。修法是用 `checkinit_hook` 手工把依赖包产物复制进本包的测试目录。

**复制清单取依赖包自己的 `installfiles`，不照抄 `ctex/build.lua` 的写法。** `ctex` 那份钩子遍历的是本包 `installfiles`，能工作是因为 `ctex` 的清单恰好覆盖了各依赖的**运行时**产物类型——按字面并非超集（`ctex` 的 `ct*.tex`／`zh*.tex` 接不住 `xeCJK` 的 `*.tex`，实测漏 13 个 `.tex`（`xunicode-symbols.tex` 加 12 个 `xeCJK-example-*.tex`）），只是漏掉的那些不参与运行时加载。xpinyin 照抄后漏了 `xeCJK` 的 `"*.cfg"`，产生**只隔离了一半**的状态：`xeCJK.sty` 取自工作树、`xeCJK.cfg` 仍取自系统 TeX Live（v3.10.4 对 v3.10.5），恰好破坏这条决策本身要达到的目的。终审盲审以 blocking 级查出。教训有两层：

- **「照抄一个能工作的实现」不等于该实现的前提在新场景下也成立**——`ctex` 的写法依赖一个未被写下来的巧合（超集关系），迁移时那个前提悄悄失效了。
- **部分隔离比不隔离更难发现**：测试全绿，`.sty` 的路径也确实是工作树的，只有逐个核对每类产物的实际加载路径才看得出来。

现行实现用 `loadfile`（不是 `dofile`——后者在全局环境执行，既无法隔离也无法用 `pcall` 兜住）读依赖包 `build.lua` 的 `installfiles`，并设两道**拒绝**判据：读不到或不是表则 `error`，空表则 `error`。`pcall` 的错误对象不构成判据（它不拒绝任何东西），而是在这两道判据触发时随 `error` 一并报出；正常情况下不打印——每次 `check` 都无条件打一行「预期行为」只会训练读者忽略它。`xeCJK` 现在必然在 `require("zip")` 处中断（空环境里 `require` 为 nil），这是预期的——`installfiles` 在那之前就已赋值——但该错误必须可见，否则将来失败点前移到赋值之前时问题无从发现。

**仍存在两个已接受的缺口**，如实记下而不假称已完全封闭。若依赖包把 `installfiles` 改成分步构造（先赋一个字面表，中途某句失败，之后再追加若干项），得到的是**残缺表**，它同时通过「是表」与「非空」两道判据，于是只复制一半而不报错——与本节要消灭的症状同型。实测确认了这一点。当前不进一步收紧是因为再严的判据都要预设依赖包的写法，反而更脆；`cp` 的 errorlevel 现已检查（复制真失败即 `error`，而非静默继续拿系统那份去测）。防线是失败时随 `error` 一并报出的 `pcall` 错误，加上「新增依赖或依赖包重构后，逐个核对测试目录里每类产物的实际加载路径」这条人工步骤。

**缺口二（现网即存在）：判据只看 `installfiles` 这张表，不看每条 glob 是否真的匹配到文件。** `xeCJK` 的 `installfiles` 含 `"*.map"` 与 `"*.tec"`，而这两类产物由 `xeCJK/build.lua` 的 `unpack_posthook` 在 `if install_files_bool then` 内经 TECkit 生成，该标志只在 `support/build-config.lua` 的 `install_files` 包装里置真，`check`／`unpack` 路径下始终为 nil。因此实测 `xeCJK/build/unpacked/` 下 `*.map`／`*.tec` 各匹配 0 个文件，`cp` 静默复制零个并返回 0，两道判据全部通过。**今天不触发**：xpinyin 现有测试都不使用 `Mapping=` 一类需要 `.tec` 的写法。但一旦将来加了这种测试，`.tec` 会命中系统 TeX Live 的 `texmf-dist/fonts/misc/xetex/fontmapping/xecjk/`（实测该目录确实有那 8 个文件），又是一次「测的其实是本机装了什么」。不在 `cp` 后加零匹配检查并 `error`，是因为现网就会当场失败；**新增依赖或新增用到 `.map`／`.tec` 的测试时，必须回到这里核对**。

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
