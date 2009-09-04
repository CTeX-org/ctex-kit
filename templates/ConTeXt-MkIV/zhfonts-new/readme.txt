from http://bbs.ctex.org/viewthread.php?tid=48176

发表于 2009-3-5 08:53  | 只看该作者

[ConTeXt] MkIV 中文排版支持的最近更新介绍

Wolfgang 写了一份新的 zhfonts.tex，默认定义了 pagella, palatino, termes,
times 四种西文字体以及 Adobe 宋体、仿宋、楷体、黑体四种中文字体。我对这
份文件进行了一点小修改，硬性设定了中文与西文字符的间距大小，并且禁止在数
学公式中直接使用中文字体，其下载见附件。

Hans 对 CJK 框架进行了调整，并且已将这部分内容的变动写入了 MkIV
Reference 文档中，见 http://www.pragma-ade.com/general/manuals/mk.pdf。
不幸的是在新版本中，中文标点压缩的功能被去除了，以后或许会出现。

最近，Hans 在最新的 ConTeXt Minimals Beta 版本中添加了中文 label 支持，
也就是说，现在基本上可以使用“第 x 章”、"图 x"、"表 x" 这样的中文本地化
label 的内建功能了，但是效果并不理想。

附件中包含了适合新版本的中文文档基本格式与所需的 zhfonts.tex。

[ 本帖最后由 LiYanrui 于 2009-3-24 11:21 编辑 ]
本主题由 Neals 于 2009-3-5 12:38 设置高亮


注意，只有 ConTeXt Minimal beta 2009.02.25 之后的版本才可以编译该示例。

