---
name: nightly-issue-heredoc-indent
description: 记 test.yml 定时失败自动开 issue 时 GitHub Actions run 块 heredoc 的两个缩进坑(YAML 剥基准缩进、sed 会误伤 diff 深缩进)，以及没实测就写反向注释两次
metadata:
  type: feedback
---

# 反思：给 test.yml 加定时失败自动开 issue 时的 heredoc 缩进两坑

## 任务

给 `.github/workflows/test.yml` 加 `file-issue-on-schedule-failure` job：定时任务失败时用
`gh issue create --body "$BODY"` 开 issue，`$BODY` 是含失败包清单、diff 正文、排查入口的多行
markdown，用 `cat <<EOF ... EOF` 构造。功能本身顺利实现（提交 `5f5591fb`），本反思只记录构造
heredoc 时踩的两个缩进陷阱，以及在没实测前把注释写成与实际相反的两次错误。

## 预期与实际

- 预期：`run: |` 里的 heredoc 写法与本地 shell 脚本一样直观，缩进只是排版问题。
- 实际：YAML 块标量的缩进语义与 shell heredoc 的缩进语义互相干扰，凡是「按 YAML 源码的视觉
  缩进去判断 shell 会收到什么」都会得出错误结论，必须解析出真实脚本文本才能确认。

## 出了什么问题

### 陷阱一：YAML 块标量 `run: |` 会剥掉公共基准缩进，heredoc 内容行必须顶着基准缩进写

workflow 里 `run:` 脚本整体在 YAML 源码中缩进 10 空格。YAML 的 `|` 块标量会把整个脚本的
**公共基准缩进剥掉**再交给 shell 执行。因此：

- heredoc 的结束标记 `EOF` 在 YAML 源里带 10 空格缩进，但 YAML 剥基准后它顶格，heredoc 能
  正常结束（普通 `<<EOF` 要求结束标记顶格，`<<-EOF` 才允许缩进）。
- 但内容行如果在 YAML 源里**相对基准多缩进**（比如 markdown 列表续行想多缩进 3 格来对齐），
  YAML 剥基准只剥公共部分，那多出的 3 格会**原样留在 body 里**，导致 markdown 渲染错误
  （≥4 空格缩进在 GFM 里会变成代码块）。

正确做法：heredoc 内容行（含列表续行）都顶着基准缩进写，与其他内容行同级，YAML 剥基准后正好
顶格进入 body。验证方法必须是`python3 -c "import yaml; ..."` 解析出 `run:` 脚本的真实文本，
逐行看 `repr()`，确认剥基准后的实际缩进——不能靠肉眼看 YAML 源，因为源里的缩进和 shell 实际
收到的文本不是一回事。

### 陷阱二：想用 sed 剥缩进会误伤 diff 正文里本就带深缩进的行

第一版误判成「heredoc 内容带 10 空格前缀需要剥」（这是基于陷阱一里错误的缩进模型，以为 YAML
不会剥基准），于是加了 `cat <<EOF | sed 's/^          //'`。

更糟的是，即便真的要剥，`sed 's/^ \{10\}//'` 会**无差别剥掉任何以 10 空格开头的行**——而贴进
body 的 `.diff` 正文里，LaTeX 节点 diff 行（如 `.....\special{pdf:...}`、`\hbox` 节点）本身就
带 ≥10 空格缩进，会被这条 sed 破坏。

正确做法：body 分三段拼接，`BODY="${HEAD}${DIFF_SECTION}${TAIL}"`。静态部分（`HEAD`/`TAIL`）
顶格写、不过任何缩进处理；diff 正文（`DIFF_SECTION`）单独构造、绝不过 sed，也不做任何缩进
变换，原样夹在中间。

### 两次「没实测就把注释写成具体结论，且与事实相反」

同一段代码的注释上连续犯了两次：

1. 第一次写「heredoc 内容带缩进前缀需要 sed 剥」——实际 YAML 已经剥了基准，sed 是多余的。
2. 更正陷阱一之后，又写「sed 不影响 diff 正文」——实际这条 sed 会误伤 diff 里本身带深缩进的
   行。

两次都是先写结论、后来实测才发现结论与事实相反，最终靠三步实测才定案：从 YAML 提取真实脚本
喂 bash 实跑、`cat -A` 看行尾与缩进、造一份带深缩进的假 diff 验证不会被破坏。

## 根因

两处失误的共同根因是同一件事：**把 YAML 源码的视觉缩进当成了 shell 实际收到的文本**。这个
假设在 heredoc 场景下是错的，因为中间多了一层 YAML 块标量剥基准缩进的转换；肉眼读 YAML 源码
看不出这层转换的结果，必须让转换真的发生一遍（解析 YAML）才能看到 shell 端的真实文本。第二次
错误（sed 误伤 diff）则是在第一个错误尚未纠正、模型本身就错的前提下，顺着错误模型继续设计
「补丁」，补丁本身又引入了新的无差别匹配问题。

## 缺失的文档或信号

`llmdoc/reference/build-and-test.md` 与仓库里其他 CI 相关文档此前没有记录「YAML 块标量剥
基准缩进」这条通用行为——此前的 workflow 改动大多是纯 shell 逻辑或简单字符串拼接，没有涉及
多行 heredoc，所以这条坑第一次在本仓的 CI 编写里现身。验证 workflow shell 逻辑此前的通用方法
（本仓已有：提取 `run:` 文本喂 bash 实跑）没有专门强调「YAML 解析」这一步对缩进语义的必要性，
容易被简化成「跑一下看报错」而漏掉缩进这种不报错、只在渲染时才显现的问题。

## 可提升为稳定文档的候选

以下几条是跨任务通用的 CI 编写规则，建议 recorder 评估是否收进
`llmdoc/reference/build-and-test.md` 或 `llmdoc/guides/`：

1. GitHub Actions `run: |` 块里用 heredoc 构造多行文本时，YAML 会剥公共基准缩进——内容行相对
   基准多出的缩进会原样漏进输出；验证要用 python 解析出真实脚本文本看 `repr()`，不能看 YAML
   源码的视觉缩进。
2. 不要用 sed 剥缩进来清理会嵌入「本身带缩进的数据」（如 diff、日志）的文本；把静态文本与数据
   分段拼接，数据段绝不过缩进变换。
3. 验证 workflow 的 shell 逻辑要提取真实脚本喂 bash 实跑，YAML lint 只保证语法、不保证 body
   渲染是否正确，二者不能互相替代。
4. 用 GitHub label 前先用 `gh api repos/.../labels/<name>` 或 `gh label list` 确认它在目标
   仓库存在；用不存在的 label 会让 `gh issue create` 失败（本次用的是仓库已有的 `upstream`，
   未使用不存在的 `ci` label）。

这与 [[1043-halign-alignment-tab-in-boundary-args]]、[[1057-fntef-nest-linebreak]] 记录过的
「没实测就把注释/结论写具体」是同一失效模式在 CI/shell 载体上的又一次发作：先写看起来合理的
结论，实测才发现方向相反。

## 后续

- 若之后还有 workflow 需要用 heredoc 拼多行 markdown/文本，先检查是否已引用本反思或
  `build-and-test.md` 里对应小节，避免重犯同一模型错误。
- 若 recorder 采纳促升，把第 1、2 条写进 `llmdoc/reference/build-and-test.md` 的 CI/CD 小节
  （紧邻 `file-issue-on-schedule-failure` 已有记载处），第 3、4 条可并入既有的「验证 workflow
  shell 逻辑」相关表述里，避免与已有内容重复表达。

## 相关

- 实现：`.github/workflows/test.yml` 的 `file-issue-on-schedule-failure` job（提交
  `5f5591fb`）。
- 文档：`llmdoc/reference/build-and-test.md` 「定时失败自动开 Issue 哨兵」一节。
