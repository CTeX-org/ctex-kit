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
| `dry_run` | yes | `true` | 默认 dry-run 防误发,真正上传前必须显式切 false |

### Jobs

**Job `prepare-announcement`** —— 生成英文 announcement:

1. Checkout to `inputs.tag` (历史 ref,保证抓到正确版本的 `.dtx`)。
2. Parse tag —— 复用 `release.yml` 同款 case 表(目前仅 `ctex` / `xeCJK`)。
3. Fetch CTAN path —— `curl https://ctan.org/json/2.0/pkg/<module>` 拿 `.ctan.path`,这样 CTAN 重组结构时不必改 `build.lua`。
4. Extract `\changes{v<ver>}` block —— python 脚本从 `.dtx` 抽出该版本所有 `\changes` 中文条目 (含续行),写 `changes-context.txt`。
5. Fetch prev CTAN announcement —— 从 CTAN API 拿上一版 announcement (若有) 作为风格参考。
6. Call Claude via `anthropics/claude-code-action@v1` —— 喂中文 `\changes` + 风格参考,要求生成 300-500 词的英文 announcement,分 NEW FEATURES / BUG FIXES / BREAKING CHANGES / DEPRECATIONS 分类。LLM `Write` 到 `announcement.md`,用 `structured_output` 兜底校验。
7. Upload `announcement.md` 为 artifact (90 天保留)。

**Job `upload-ctan`** (needs prepare-announcement):

1. 装最小 TeX Live (只要 `l3build` + `luatex`,**不装字体 / Unihan / makeindex** —— 不重新打包)。
2. Download `announcement` artifact。
3. `gh release download <tag> --pattern '*.zip'` 拿 GH Release zip,改名为 `<dir>/<module>-ctan.zip` (l3build upload 期待的位置/名字)。
4. `cd <dir> && l3build upload --file ../announcement.md --email <email> [--dry-run]`。
   - `CTAN_UPLOADER` / `CTAN_EMAIL` 通过 env 注入,`support/build-config.lua` 的 `ctex_kit_uploadconfig()` 在 build.lua 加载时从 env 读。
5. 非 dry-run + 上传成功 ⟹ `gh release edit <tag> --prerelease=false --latest` 翻成正式版。
6. Step summary 输出包 / 版本 / CTAN path / 上传者 / mode / 结果。

### 配置约束

- 各包 `build.lua` 须有 `uploadconfig = ctex_kit_uploadconfig{...}` (目前只 `xeCJK` / `ctex`)。
- 仓库 Secrets 须有 `ANTHROPIC_API_KEY`(已配); 可选 `ANTHROPIC_BASE_URL`、`PAT_TOKEN`。
- `uploader`/`email` 不落 git —— workflow input 走 env,build.lua 通过 `os.getenv("CTAN_UPLOADER")` 读。
- 第一次发新包前,记得在 CTAN 网页填一次表(`update=false`)。本仓库当前 `uploadconfig.update=true`,即仅用于已存在的包发新版本。

### 本地手跑 (调试用)

`l3build upload --dry-run` 在 build.lua 所在目录跑,前置环境:

```bash
export CTAN_UPLOADER="Liam Huang"
export CTAN_EMAIL="liamhuang0205@gmail.com"
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

