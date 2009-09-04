from http://bbs.ctex.org/viewthread.php?tid=51583

[ConTeXt] 一个 MkIV 中文字体模块
本帖最后由 LiYanrui 于 2009-7-30 07:40 编辑

折腾了一下午，总算有了一点点成就，但是 ConTeXt 宏编程语法，对我来说还是
像天书一样。

下载 t-zhfonts.tex (2.82 KB)
下载次数: 16
2009-7-29 23:44
，扔到 $TEXMFLOCAL/tex/context/third/t-zhfonts 目录里，然后：

   1. $ context --generate

复制代码
刷新一下“ConTeXt 数据库”。

这个模块的使用方法如下：

   1. \usemodule[zhfonts]
   2. \setupbodyfont[zhfonts,rm,24pt]
   3. \starttext
   4.

   5. 世界 Hello World 你好\par
   6. {\bf 世界 Hello World 你好}\par
   7. {\it 世界 Hello World 你好}\par
   8. {\bi 世界 Hello World 你好}\par
   9.

  10. {\ss 世界 Hello World 你好}\par
  11. {\ss\bf 世界 Hello World 你好}\par
  12. {\ss\it 世界 Hello World 你好}\par
  13. {\ss\bi 世界 Hello World 你好}\par
  14.

  15. {\tt 世界 Hello World 你好}\par
  16. {\tt\bf 世界 Hello World 你好}\par
  17. {\tt\it 世界 Hello World 你好}\par
  18. {\tt\bi 世界 Hello World 你好}\par
  19.

  20. \stoptext

复制代码
示例的编译结果见 test.pdf (27.29 KB)
下载次数: 20
2009-7-29 23:45
。

打开这份 pdf，可以看到中文字体只有一种，是 AdobeSongStd-Light，英文字体
很齐全。这是因为我在 t-zhfonts 模块中对 Serif、Sans、Mono 定义了预设值，
如下：

   1. \setupzhfonts[Serif][AdobeSongStd-Light][TeXGyrePagella-Regular]
   2. \setupzhfonts[SerifBold][AdobeSongStd-Light][TeXGyrePagella-Bold]
   3.
\setupzhfonts[SerifItalic][AdobeSongStd-Light][TeXGyrePagella-Italic]
   4.
\setupzhfonts[SerifBoldItalic][AdobeSongStd-Light][TeXGyrePagella-BoldItalic]
   5.

   6. \setupzhfonts[Sans][AdobeSongStd-Light][TeXGyreHeros-Regular]
   7. \setupzhfonts[SansBold][AdobeSongStd-Light][TeXGyreHeros-Bold]
   8. \setupzhfonts[SansItalic][AdobeSongStd-Light][TeXGyreHeros-Italic]
   9.
\setupzhfonts[SansBoldItalic][AdobeSongStd-Light][TeXGyreHeros-BoldItalic]
  10.

  11. \setupzhfonts[Mono][AdobeSongStd-Light][TeXGyreCursor-Regular]
  12. \setupzhfonts[MonoBold][AdobeSongStd-Light][TeXGyreCursor-Bold]
  13.
\setupzhfonts[MonoItalic][AdobeSongStd-Light][TeXGyreCursor-Italic]
  14.
\setupzhfonts[MonoBoldItalic][AdobeSongStd-Light][TeXGyreCursor-BoldItalic]

复制代码
当然，你可以像上面那样，在自己的文档中使用 \setupzhfonts 进行字体设定。


本帖最后由 LiYanrui 于 2009-8-1 08:35 编辑

这个东西大致是照着 Wolfgang 的 simplefonts 写的，不过 Wolfgang 的
simlefonts 模块对于中文用户而言，运行的有点慢，并且在设置字号方面有些问
题，所以我才 diy 了一个，现在只是够自己用。

补充：

昨晚，Wolfgang 发给我一封邮件，指出：

the test file 33 will show you my module is not as slow as you think
and don't have to stay behind your zhfonts module.

我测试了一下，果然，甚至还有点慢。


