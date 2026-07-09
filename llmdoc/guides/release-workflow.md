# Release 自动化流水线

## 两阶段 release 模型

release 流程明确分为两个阶段:

1. **公测阶段 (GitHub Release)** —— 推 tag 自动触发 `release.yml`,跑 `l3build ctan` 打 zip,生成中文 release notes,发布到 GitHub Release 并标 `--prerelease`。公测用户可下载 zip 自测。这一阶段**不**触达 CTAN。
2. **正式发布阶段 (CTAN upload)** —— 公测无误后,在 GitHub UI **手动**触发 `release-ctan-upload.yml`(`workflow_dispatch`),把同一个 GH Release zip 投递到 CTAN。CTAN reviewer 接收后正式发布。本工作流上传成功且非 dry-run 时,自动把 GH Release `--prerelease=false --latest`。

两个工作流共享同一 zip 资产,**不重新打包**——确保公测用户拿到的 zip 与 CTAN 用户拿到的字节级一致。

## 阶段一:`release.yml` 触发与适用范围

`.github/workflows/release.yml` 在推送以下 tag 时触发:

- `ctex-v*`
- `xeCJK-v*`
- `CJKpunct-v*`
- `zhnumber-v*`
- `xCJK2uni-v*`
- `xpinyin-v*`
- `zhmetrics-v*`
- `zhmetrics-uptex-v*`
- `zhspacing-v*`

工作流会先解析 tag 前缀，把包名、目录、`l3build` 模块名、目标 `.dtx` 与版本号映射出来；未知格式会直接失败。release 自动化现已覆盖全部 9 个 CTAN 发布单元。其中 `zhmetrics-uptex` 和 `zhspacing` 没有 `.dtx` 文件，因此 release notes 生成会直接回退到 git log 或最小占位说明。

## 流水线阶段

该工作流在 `ubuntu-latest` 上运行，稳定阶段可以分为：

1. `Parse tag`：识别当前 tag 对应的包目录、模块名和版本号。
2. `Install TeX Live`：通过 `TeX-Live/setup-texlive-action@v4` 按 `.github/tl_packages` 安装最小可用环境。
3. `Install zhmakeindex`：从 `Liam0205/zhmakeindex` 的最新 release 下载 Linux 二进制，供文档索引与 CTAN 打包使用。
4. `Install CJK fonts`：安装 CI 所需字体并刷新 fontconfig 缓存。
5. `Download Unihan data (xeCJK)`：仅在 `xeCJK` release 时预先下载 `support/Unihan.zip`，避免 `xeCJK/build.lua` 在构建期再联网拉取 Unicode 数据。
6. `Build CTAN zip`：在目标子目录运行 `l3build ctan`。
7. `Prepare release asset`：把 `<module>-ctan.zip` 重命名为 `<module>-v<ver>.zip`，作为 GitHub Release 附件。
8. `Generate release notes`：优先从对应 `.dtx` 的 `\changes{v<ver>}{...}{...}` 条目提取发布说明，失败时再回退到 git log。
9. `Wait for test CI to pass`：在真正发布前轮询 `test.yml` 对应 `head_sha` 的最新 run，确认测试工作流成功。
10. `Create GitHub Release`：若同名 release 已存在则先删除，再创建新的 prerelease。

## 并行与门控模型

release 工作流把“产物准备”和“发布门控”分成两个层次理解：

- 构建、打包、asset 重命名、release notes 生成这些步骤都只依赖当前 tag 对应源码，可以在 release 任务内部先完成。
- 只有最后的 `Create GitHub Release` 需要等待 `.github/workflows/test.yml` 针对同一提交 SHA 成功。

门控实现方式是调用 GitHub Actions API：

- 查询路径：`actions/workflows/test.yml/runs?head_sha=<sha>&per_page=1`
- 轮询状态：最长 60 次，每次间隔 30 秒
- 成功条件：最新 workflow run 的 `conclusion == success`
- 失败条件：run 已 `completed` 但结论不是 `success`，或 30 分钟超时

这意味着 release 不会在一开始就阻塞等待测试，而是先把可并行准备的内容做完，只在发布前做最后一道 CI 门控。

## Release notes 生成约定

release notes 的稳定优先级是：

1. 先从目标 `.dtx` 中匹配 `\changes{v<ver>}{...}{...}` 条目。
2. 解析连续的注释续行，把常见文档命令转换为 Markdown 近似表达，例如把 `\pkg{...}`、`\texttt{...}` 转成反引号代码样式。
3. 若没有提取到有效 `\changes` 条目，再找上一版本 tag 到当前 tag 之间、且限定到目标目录的 git log。
4. 若 git log 也为空，则退化为单行的 `Release <pkg> v<ver>`。

维护上的含义是：若希望 release notes 稳定、可读且不依赖提交历史清洗，就应优先维护各包 `.dtx` 中的 `\changes` 条目。

### `scripts/extract-changes.py` 参数语义（#961）

脚本用法：`extract-changes.py <dtx_path...> <version|all> [-o <file>]`。

- **单版本模式**（`<version>` 传具体版本号，如 `v3.10.0`）：只抽取该版本的 `\changes{v3.10.0}{...}{...}` 条目，输出与升级前字节完全一致——这是 `release.yml` / `release-ctan-upload.yml` 的既有消费路径，兼容性是硬约束，任何改造都不能引入字节级差异。
- **`all` 模式**（#961 新增）：一次性抽取 dtx 中全部版本的 `\changes`，按语义化版本从新到老分组，每版本前加 `## [pkg-vX.Y.Z](https://github.com/CTeX-org/ctex-kit/releases/tag/pkg-vX.Y.Z)` 小标题——**只有 `all` 模式才输出版本标题**，用于生成完整的 `CHANGELOG.md`（见 `llmdoc/reference/build-and-test.md` 的 `check-changelog.yml` 一节）。包名前缀由多个 `.dtx` basename 的 `os.path.commonprefix` 推断（`ctex` 6 个拆分 dtx → 前缀 `ctex`；`zhmetrics` 目录里实际 dtx 是 `zhmCJK.dtx` → 推断前缀 `zhmCJK`，与目录名/发布 tag 习惯 `zhmetrics-*` 不一致，生成的版本链接是已知死链，见 [[961-changelog-gate-no-write-perm]]）。
- **`-o <file>` 参数**（#961 新增）：脚本自己以 `encoding="utf-8"` + `newline="\n"` 写文件，不依赖 shell 重定向。生成 `CHANGELOG.md` 必须用 `-o` 而非 `python3 ... > CHANGELOG.md`——Windows PowerShell 5 的 `>` 默认产出 UTF-16LE + CRLF，会让字节级 `git diff` 门禁必然失败。不传 `-o` 时行为不变（打印到 stdout），`release.yml` / `release-ctan-upload.yml` 两处既有调用点无需改动。

## 已有 release 的重建语义

`Create GitHub Release` 前会先执行：

- `gh release delete <tag> --yes || true`

然后再重新创建同名 release，并始终带 `--prerelease`。因此该自动化的语义不是“若已存在则跳过”，而是“用当前 tag 对应产物和说明重建 prerelease”。

## 与 CTAN 打包入口的关系

release 自动化并不绕过包内 `l3build` 逻辑。真正的打包仍在目标目录调用 `l3build ctan`，所以：

- 共享行为仍由 `support/build-config.lua` 决定；
- 包级文档驱动、安装文件、测试目录和构建钩子仍由各自 `build.lua` 决定；
- release workflow 只是增加了 tag 触发、资产整理、说明生成和 GitHub Release 发布这层外包装。

因此，排查 release 构建失败时，先区分问题是在 workflow 编排层，还是已存在的 `l3build` / `build.lua` 打包链本身。

## 阶段二:`release-ctan-upload.yml` CTAN 投递

公测无误后,通过 GitHub UI 触发本工作流。**仅支持 `workflow_dispatch`**,无 push trigger;`if: github.repository == 'CTeX-org/ctex-kit'` fence 防 fork 上误跑。

### Inputs

| input | required | 默认 | 含义 |
|---|---|---|---|
| `tag` | yes | — | 已发布的 GH Release tag,如 `xeCJK-v3.10.0` |
| `uploader` | yes | — | CTAN 上传者真名 (CTAN reviewer 回邮抬头) |
| `email` | yes | — | CTAN 上传者 email (reviewer 回邮地址) |
| `note` | no | `''` | CTAN 内部备注 (≤4096 byte),写给 CTAN reviewer 看,如维护者变更说明。留空则不写 note 字段 |
| `dry_run` | yes | `true` | 默认 dry-run 防误发,真正上传前必须显式切 false |
| `announce` | yes | `true` | 是否生成 + 投递英文 announcement。minor changes (typo / 注释 / 小补丁) 可设 `false` 跳过,节省 LLM 调用并避免 CTAN 邮件列表噪声 |

`announce=false` 时,`prepare-announcement` job 中所有 LLM 相关 step (Extract changes / Fetch prev announcement / Install Claude CLI / Generate announcement / Verify / Upload artifact) 都用 `if: inputs.announce == true` 跳过;`upload-ctan` job 改由 `Create empty announcement.md` step 写一个空 `announcement.md` 占位。l3build `upload --file` 仍总是传 `announcement.md`(不分支),空文件被 l3build 读到空串、trim 后走 "Empty announcement: No ctan announcement will be made" 放行路径——这是因为 l3build 的 `file_contents()` 实现是 `assert(open(filename))`,文件不存在会直接抛错而非返回 nil,故必须写空文件而非让 step 缺失。

`note` 的字节上限校验在 workflow 内提前完成 (见下文 `upload-ctan` job 的 `Validate note length` step),不必等 l3build POST 到 CTAN 服务端才报错。

### 权限控制 (per-package environment gate)

只要对仓库有 write 权限的用户都能在 GH UI 触发 `workflow_dispatch`。为防止「任意 collaborator 把任意包发到 CTAN」,`upload-ctan` job 在 **`dry_run=false` 时**进 environment `ctan-release-<module>` (名字全小写,跟 l3build `module` 字段),由该 environment 配置的 required reviewers 在 GH UI 点 Approve 才放行。

- `dry_run=true` ⟹ 不进 environment,任意 collaborator 可跑测试
- `dry_run=false` ⟹ 进 environment,等 reviewer approve 才真上 CTAN

需先在 **Settings → Environments** 建好对应 environment (名缺失会让 job fail 在 "Environment not found"):

| environment | 适用包 | required reviewers |
|---|---|---|
| `ctan-release-xecjk` | xeCJK | (由 admin 配置) |
| `ctan-release-ctex`  | ctex   | (由 admin 配置) |
| `ctan-release-zhlineskip` | zhlineskip | RuixiZhang42 only |

推荐 **wait timer 5 分钟** —— approve 后等 5 分钟才能启动,防纯手贱秒批。其他包接入时按 `ctan-release-<lowercase-module>` 命名添加。

### Jobs

**Job `prepare-announcement`** —— 生成英文 announcement:

1. Checkout to `inputs.tag` (历史 ref,保证抓到正确版本的 `.dtx`)。
2. Parse tag —— 复用 `release.yml` 同款 case 表(目前 `ctex` / `xeCJK` / `zhlineskip`)。
3. Fetch CTAN path —— `curl https://ctan.org/json/2.0/pkg/<module>` 拿 `.ctan.path`,这样 CTAN 重组结构时不必改 `build.lua`。
4. Extract `\changes{v<ver>}` block —— 复用 `scripts/extract-changes.py`(与 `release.yml` 生成 GH Release body **共用同一脚本**)从 `.dtx` 抽出已清洗的 markdown bullet 列表,写 `release-notes.md`。提取前先 `sed` 剥离 `-rc<N>` / `-pre` / `-alpha` / `-beta` 后缀,让 RC tag 共享 base 版本的 `\changes` 条目。**两个 workflow 共用提取 + 命令清洗脚本是为了保证 CTAN announcement 与 GH Release body 的事实层字面一致**——曾出现 LLM 直接读 `\changes` 原文时凭空脑补出 dtx 里不存在条目的事故 (zhlineskip-v1.0f, PR #928)。
5. Fetch prev CTAN announcement —— 从 CTAN API 拿上一版 announcement (若有) 作为**风格 / 措辞参考**,不是事实源。
6. Call Claude via `anthropics/claude-code-action@v1` —— 把 `release-notes.md` 作为**唯一事实源**,要求 LLM **忠实翻译**为英文 announcement:一条中文 → 一条英文一一对应,严禁新增 / 合并 / 外推任何 release-notes.md 之外的事实,字数随条目数自适应 (不强行凑长)。分 NEW FEATURES / BUG FIXES / BREAKING CHANGES / DEPRECATIONS,空类不留标题。LLM `Write` 到 `announcement.md`,用 `structured_output` 兜底校验。
7. Upload `announcement.md` 为 artifact (90 天保留)。

**Job `upload-ctan`** (needs prepare-announcement):

1. 装最小 TeX Live (只要 `l3build` + `luatex`,**不装字体 / Unihan / makeindex** —— 不重新打包)。
2. Download `announcement` artifact。
3. `gh release download <tag> --pattern '*.zip'` 拿 GH Release zip,改名为 `<dir>/<module>-ctan.zip` (l3build upload 期待的位置/名字)。
4. `Validate note length` —— 若提供了 `note`,用 `wc -c` 按 **byte** 数校验 ≤4096(bash `${#NOTE}` 在 `LANG=C.UTF-8` 下数的是字符数,中文会让校验偏宽,故必须按 byte 算);超限直接 fail。note 经 env 传入而非 `${{ }}` 字符串插值,防 shell 元字符注入。
5. `cd <dir> && l3build upload --file ../announcement.md --email <email> [--dry-run]`。
   - `CTAN_UPLOADER` / `CTAN_EMAIL` / `CTAN_NOTE` 通过 env 注入,`support/build-config.lua` 的 `ctex_kit_uploadconfig()` 在 build.lua 加载时从 env 读。
   - `note` 走 `ctex_kit_env_or_nil("CTAN_NOTE")`:input 留空时 GH Actions 注入空串 `""`,该工具函数把 `nil` 和 `""` 一并视为未设置,从而跳过 `note` 字段(避免给 CTAN 提交空 note)。l3build CLI 不暴露 `--note`,仅认 `uploadconfig.note` / `note_file`,故只能走 env。
6. 非 dry-run + 上传成功 ⟹ `gh release edit <tag> --prerelease=false --latest` 翻成正式版。
7. Step summary 输出包 / 版本 / CTAN path / 上传者 / mode / announcement (sent/skipped) / note / 结果。

### 配置约束

- 各包 `build.lua` 须有 `uploadconfig = ctex_kit_uploadconfig{...}` (目前 `xeCJK` / `ctex` / `zhlineskip`)。
- 仓库 Secrets 须有 `ANTHROPIC_API_KEY`(已配); 可选 `ANTHROPIC_BASE_URL`、`PAT_TOKEN`。
- `uploader`/`email` 不落 git —— workflow input 走 env,build.lua 通过 `os.getenv("CTAN_UPLOADER")` 读。
- 第一次发新包前,记得在 CTAN 网页填一次表(`update=false`)。本仓库当前 `uploadconfig.update=true`,即仅用于已存在的包发新版本。

### 本地手跑 (调试用)

`l3build upload --dry-run` 在 build.lua 所在目录跑,前置环境:

```bash
export CTAN_UPLOADER="Liam Huang"
export CTAN_EMAIL="liamhuang0205@gmail.com"
# 可选: 给 CTAN reviewer 的内部备注 (≤4096 byte), 不设则不写 note 字段
# export CTAN_NOTE="Maintainer changed from ... to ..."
# 把 GH Release 上下载的 zip 改名为 <module>-ctan.zip 放在包目录
cd xeCJK && l3build upload --dry-run --file ../announcement.md
```

### 失败模式

| 现象 | 原因 / 修复 |
|---|---|
| `Missing zip file '<module>-ctan.zip'` | 上一步 download/rename 没就位; 检查 GH Release 有没有 `*.zip` asset |
| `CTAN API 没返回 .ctan.path` | 包名 (`module`) 错; 或包还没在 CTAN 注册过 (第一次发要手工填表) |
| LLM 生成的 announcement 为空 | claude-code-action 出错; 看 `Generate English announcement` step 日志, 必要时手填 `announcement.md` 再 re-run |
| `Name of uploader` 字段空 | `CTAN_UPLOADER` env 未透传; 检查 `Run l3build upload` step env block |
| `CTAN note 超过 4096 byte 上限` | `note` input 过长; `Validate note length` step 提前 fail。缩短 note 后重新触发 workflow (注意中文按 byte 算,1 汉字 ≈ 3 byte) |

