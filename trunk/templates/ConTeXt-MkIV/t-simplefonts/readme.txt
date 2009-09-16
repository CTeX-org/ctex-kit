update:
2009-09-16  ConTeXt Minimals 升级到最新版本
            t-simplefonts 升级到最新版本 1612d942f218, 2009-09-15
            test.tex 里字体属性按照新的 t-simplefonts 要求加上 font 后缀。
============================
from http://bitbucket.org/wolfs/simplefonts/ at rev e93f68af160e


from http://bbs.ctex.org/viewthread.php?tid=49623


[ConTeXt] MkIV simplefonts module
Wolfgang Schuster 最近写了一个用于设定不同语言字体的模块（现在可以用它替
换掉丑陋的 zhfonts.tex 了）。

项目主页：http://bitbucket.org/wolfs/simplefonts/

现在，中/英文混合文档格式如下：

   1. \usemodule[simplefonts]
   2.

   3. % 设置西文字体
   4. \setmainfont{TeXGyrePagella}
   5. \setsansfont{TeXGyreHeros}
   6. \setmonofont{TeXGyreCursor}
   7.

   8. % 设置中文字体
   9. \setcjkmainfont[AdobeSongStd][regular={*
Light},italic={AdobeKaitiStd Regular},bold={AdobeHeitiStd
Regular},bolditalic={AdobeHeitiStd Regular}]
  10.

  11. \setcjksansfont[AdobeKaitiStd][bold={AdobeHeitiStd
Regular},bolditalic={AdobeHeitiStd Regular}]
  12.

  13. \setcjkmonofont[AdobeFangsongStd][bold={AdobeHeitiStd
Regular},bolditalic={AdobeHeitiStd Regular}]
  14.

  15. % 启用中文断行
  16. \setscript[hanzi]
  17.

  18. % 正文
  19. \starttext
  20.

  21. ... ... ...
  22.

  23. \stoptext

复制代码
附件是一份测试示例以及输出结果。

[ 本帖最后由 LiYanrui 于 2009-5-13 13:23 编辑 ]

    test.tex (1.06 KB)

    下载次数:19

    2009-5-8 08:38

    test.pdf (58.94 KB) 

