# 决策：#1010 开放实验性命令边界注册接口

## 背景

#992 把 xeCJK 对命令边界的处理统一到 capture/register 框架：命令按照实际
排出的首尾类别恢复间距，具体注册只需选择与节点结构相符的策略。自 v3.10.0
以来积累的内建补丁证明，恢复算法可以共用，但目标命令的参数读取方式、节点
结构和加载时机仍需要逐项判断。

#1010 据此决定向熟悉 TeX 节点和命令定义的用户开放实验性注册入口。这个入口
复用现有五种注册函数，不另建一套边界恢复算法，也不承诺自动判断任意命令应当
采用哪一种策略。

## 接口契约

用户通过 `\xeCJKsetup` 声明一个控制序列、策略和可选模式：

```tex
\xeCJKsetup
  {
    experiment/boundary-register =
      {
        command  = \mycommand,
        strategy = box,
        mode     = auto
      }
  }
```

- `command` 必须直接接收且只接收一个控制序列，不接受不带反斜线的名称字符串。
  带 `@` 的命令由用户在 `\makeatletter`／`\makeatother` 中声明；带 `_`、`:` 的
  LaTeX3 命令由用户在 `\ExplSyntaxOn`／`\ExplSyntaxOff` 中声明。
- 声明按全局状态保存，即使 `\xeCJKsetup` 位于分组内，注册也不会随分组结束而
  消失。
- 接口只允许新增注册，不提供反注册，也不允许覆盖 xeCJK 已经处理的命令。

五种策略及其 `mode` 规则如下：

| `strategy` | 适用的可观察节点结构 | 允许的 `mode` |
| --- | --- | --- |
| `box` | 命令结束后留下一个末尾 hbox | `auto`（默认）、`default` |
| `wrapped-box` | 命令直接写出多个节点，需要临时透明盒子收集 | `auto`（默认）、`default` |
| `stream` | 可见内容直接写入当前列表 | `auto`（默认）、`default`、`first-default` |
| `transparent` | 只写出锚点、write、颜色 special 等不可见节点 | 不接受 `mode` |
| `post-transparent` | 只能在命令结束后观察到零尺寸末尾盒子 | 不接受 `mode` |

`auto` 使用 capture 实际观察到的首尾类别；`default` 固定首尾都为 Default；
`first-default` 只固定首端为 Default，末端仍取实际输出。选择错误的策略可能改变
目标命令的参数读取或节点次序，因此这一接口保持为实验性，并要求使用者以去掉
命令包装后的直接输入作为比较基准。

## 注册生命周期

用户声明不会立即修改目标命令。xeCJK 按以下顺序处理：

1. 声明时校验 `command`、`strategy` 和 `mode`，并把有效记录全局保存。
2. 保存记录时立即检查目标是否已经由 xeCJK 处理，尽早拒绝已知冲突。
3. 到导言区末尾，在全部 xeCJK 内建注册之后，再次检查冲突；无冲突时才调用
   对应的内部注册函数。
4. LaTeX 在普通 `\AtBeginDocument` 代码执行完后安装命令 hook；xeCJK 随后检查
   已应用注册的目标是否已经定义。因此，在普通 `\AtBeginDocument` 中才定义的
   命令可以注册，正文开始后才定义的命令会报告未定义，而且不会意外获得 hook。
5. 导言区结束后关闭声明窗口；正文期再次使用该选项会报告错误，也不会修改已经
   保存的记录。

冲突检查必须同时查询两张表：

- 通用注册表记录通过 `box`、`wrapped-box`、`stream`、`transparent` 和
  `post-transparent` 注册函数安装的命令 hook；
- 专用适配器保留表记录必须直接重定义扫描器、参数处理函数或内部排版入口的
  命令。

两张表的并集才表示“这个命令已经由 xeCJK 处理”。只查询通用注册表会漏掉
`\verb`、`\Url@z`、codedoc、ulem 和 listings 等专用入口，使用户 hook 与内部
适配器重复处理同一命令。保存和导言区末尾应用两个阶段必须使用同一个并集判断，
才能同时覆盖已知冲突和导言区内后来加载的宏包。

## 明确限制

- `auto` 只观察 capture 能够看到的 CJK／Default 类别，不分析未知命令怎样消费
  参数。参数以公式开始或结束时，#1002 还需要在目标命令的可见正文排完之前确认
  实际 math 节点；五种通用策略不会自动取得这项能力。
- `\verb`、URL、listings、ulem 等特殊扫描器或内部排版入口可能不能使用普通
  LaTeX 命令 hook。xeCJK 已处理的入口会通过保留表拒绝重复注册；其他同类命令
  仍需使用者理解其真实扫描点，不能只根据公开命令名选择策略。
- 注册后若目标命令被重新定义，原先选择的策略和参数结构可能不再成立。用户必须
  重新验证直接输入比较；本接口不提供覆盖或反注册来自动迁移旧 hook。
- TeX 节点不记录 glue 来源等既有机制边界仍然存在；用户注册不会扩大
  capture/register 能够可靠识别的节点范围。

随包示例 `xeCJK-example-boundary-register.tex` 展示五种策略、`00/10/01/11`
四种源码空格、左右边界以及 `xCJKecglue=false/true`。示例保留公式负例，用来
说明何时通用注册已经不足，而不是把参数公式适配误写成 `auto` 的一般能力。

## 验证状态

- `boundary-register-api01` 对五种策略、三种允许的模式、分组内声明、带 `@` 和
  LaTeX3 `_`、`:` 的控制序列、普通 `\AtBeginDocument` 定义、四种源码空格、
  左右单边界以及 `xCJKecglue=false/true` 共执行 288 项比较，失败数为 0。
- `boundary-register-api02` 固定非控制序列、缺项、非法选择和组合、重复声明、
  通用内建冲突、专用适配器冲突、未定义目标和正文期声明等诊断；拒绝 `\verb`
  后还实际调用其专用扫描器，确认原行为没有被用户 hook 破坏。
- 两个新增测试使 xeCJK 标准回归总数从 109 项增加到 111 项，当前为 111／111。

## 相关资料

- Issue：#992、#1002、#1010
- 架构：[[../../architecture/xecjk-architecture]]
- 内部框架决策：[[992-command-boundary-capture-register]]
- 公式参数适配：[[1002-inline-math-boundary-oracle]]
- 测试：[[../../reference/build-and-test]]
- 反思：[[../reflections/1010-boundary-register-public-api]]
