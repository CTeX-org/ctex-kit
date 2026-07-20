# Issue #998 资产

行内公式 `\mbox{$x$}` 与标尺盒 `\mbox{\vrule ...}` 在 CJK 上下文中的边界
间距与直接输入不一致; 纯西文上下文不受影响。

根因 (机制边界): math 与 rule 不触发 XeTeX interchar class 转换,
capture 观察不到任何首尾类别, box 策略将其按"无可见输出"处理——
原样恢复入口 marker 与源码空格, 违反输出等价契约。
v3.10.3 与 PR #999 的 MWE 输出一致 (预存缺陷, 非 #999 引入)。

- `issue998-mwe.tex` — issue 原 MWE (补字体声明)。
- `issue998-confirm.png` — 四个 DELTA: -6.66pt / 0 / -3.33pt / 0。

Workaround (PR #999 之后):
- math: 左侧有源码空格即正常 (`前 \mbox{$x$} 后`); 无空格场景可写
  `前~\mbox{$x$}` 或 `前\CJKecglue\mbox{$x$}`。
- rule: 改用原语 `\hbox{\auditrule}`, 或在 `\mbox` 后加 `\kern0pt`
  (`前\mbox{\auditrule}\kern0pt\ 后`)。
