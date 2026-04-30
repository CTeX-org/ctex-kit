# Release 自动化流水线

## 触发与适用范围

`.github/workflows/release.yml` 为当前仓库新增了 GitHub Release 自动化入口，仅在推送以下 tag 时触发：

- `ctex-v*`
- `xeCJK-v*`
- `CJKpunct-v*`

工作流会先解析 tag 前缀，把包名、目录、`l3build` 模块名、目标 `.dtx` 与版本号映射出来；未知格式会直接失败。因此当前 release 自动化只覆盖这三个发布单元，而不是 `ctan.lua` 中的全部 CTAN 包。

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
