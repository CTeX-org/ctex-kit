ctex宏包 v0.8  2006/06/09
=========================

ctex宏包提供了一个统一的中文LaTeX文档框架，底层支持CCT和CJK两种中文
LaTeX系统。ctex宏包提供了编写中文LaTeX文档常用的一些宏定义和命令。

ctex宏包需要CCT系统或者CJK宏包的支持。主要文件包括ctex.sty、
ctexart.cls、ctexrep.cls、和ctexbook.cls。

ctex 宏包由ctex.org 制作并负责维护。




安装说明
========

1. 建立 localtexmf/tex/latex/ctex 目录，将 ctex.zip 中的
   所有文件解压并拷贝到该目录下。

2. 运行批处理命令 install 得到宏包文件和配置文件。

3. 运行批处理命令 install doc 得到宏包文件说明文件。

(你也可以运行批处理命令 install all 一次性得到所有文档。)

4. 刷新文件名数据库。

5. 仔细阅读宏包说明文件中的使用帮助。


Windows 以外的操作系统请参考下面的说明：
1. 运行 latex ctex.ins 得到宏包文件和配置文件。

2. 运行 latex ctex.dtx 得到宏包说明文件。

3. 说明文件的索引生成需要特殊处理：
makeindex -s gind.ist -o ctex.ind ctex.idx
makeindex -s gglo.ist -o ctex.gls ctex.glo
然后重新编译 ctex.dtx 文件就可以得到正确的索引和修改记录。




宏包的主要特点
==============

1. 对CJK的完整封装，提供对用户友好的设置命令
2. 对CCT的良好支持，使得底层的中文系统对于普通用户是透明的
3. 符合中文习惯的缺省文档风格，降低了初学者使用中文LaTeX的难度
4. 全新中文标题处理方案，解决了原来GB.cap文件和标准文档类
的兼容性问题
5. 彻底解决中文编号问题，包括PDF书签、引用中的中文数字的
正确处理（这个花了我最多时间）
6. 详细的使用说明，便于大家学习使用
7. 完整的内部实现和接口说明，为将来改进以及进一步扩展打下
良好基础




版本更新
========

v0.8  2006/06/09
    将 ctex.sty 文件分割为 ctex.sty 和 ctexcap.sty，后者只支持标准文档类
    增加对 \stepcounter 的重定义，以和 calc 宏包兼容

v0.7f  2006/04/12
    采用修改 \AtBeginDocument 和 \AtEndDocument 命令的方式来设置 CJK 环境，以减少宏包冲突

v0.7e  2006/03/22
    使用 \DeclareRobustCommand 命令来定义 \CTEXnumber 和 \CTEXcounter
    除去 \CTEXdigits 和 \CTEX@getdigit 命令带来的多余空格

v0.7d  2005/12/28
    在 fntef 类宏包后使用 \normalem 恢复 \em 宏的缺省定义

v0.7c  2005/12/20
    增加对 \if@mainmatter 的判断，以兼容 amsbook 宏包

v0.7b  2005/12/09
    调整宏包导入位置，解决 fntef 类宏包早于相应中文宏包导入的问题

v0.7a  2005/11/28
    将 ctex.cfg 文件的读取时间前移，使得导言中的设置命令优先

v0.7   2005/11/25
    支持在导言区中使用中文和章节标题设置命令（感谢 tercelxy 的建议）
    增加 CJKfntef 宏包和 CCTfntef 宏包的统一接口（感谢 chenyu_21cn 的建议）

v0.6b  2005/11/07
    将节以下编号和标题之间的空距定义转移到相应的 aftername 变量中

v0.6a  2005/09/30
    增加对 \CCT@set@fontsize 的判断

v0.6   2005/09/24
    针对 cct 0.6180 的修改
    \set@fontsize: cct 从 0.6180 开始将宏 \oset@fontsize 改为 \CCT@set@fontsize

v0.5c  2004/09/29
    避免重复执行设置 CJK 环境结束语句

v0.5b  2004/09/29
    改变设置 CJK 环境结束语句的 \AtEndDocument 执行的位置，以减少宏包冲突

v0.5a  2004/09/06
    修改图表标题分隔符设置中的错误

v0.5  2004/08/23
    General: Move Chinese definitions from ctex.cfg to ctex.def

v0.4d  2004/08/14
    \ps@fancy: 增加对 mainmatter 的判断
    \refstepcounter: 修改 \ref 命令，不再包含除编号外的内容

v0.4c  2004/07/26
    \addtocounter: 增加判断以避免嵌套定义 \setcounter 和 \addtocounter

v0.4b  2004/07/13
    \baselinestretch: 把 \baselinestretch 从 1.2 改为 1.3

v0.4a  2004/05/15
    \CTEXdigits: 增加 \CTEXdigits 命令
    \ziju: 修改 CCT 的字距命令使得缩进保持一致

v0.4  2004/05/13
    General: 如果指定了标准的 LaTeX 字体大小，则不使用中文字号
        中文字号定义改为直接使用 pt 为单位
    \zihao: 删除 \CTEX@fontsize 命令，改为直接使用 \fontsize 命令

v0.3b  2004/05/11
    General: 增加 fancyhdr 选项

v0.3a  2004/04/30
    General: 修改命令 \CCTpuncttrue 的拼写错误

v0.3  2004/04/24
    General: 对页眉设置进行微调
        对中文标题的章节编号格式进行调整，去掉 \S
        修改为使用 \chinese 命令以避免产生错误
        修正 sub3section 和 sub4section 选项无效的问题
        增加对图表标题分隔符的设置
    \ps@fancy: 解决与 fancyhdr 的冲突

v0.2d  2004/04/23
    General: Change option c5size to base on 10pt basic class
        补上字号定义中行间距参数中缺少的 \CTEX@bp
        修改缺省的字号大小

v0.2c  2004/02/13
    General: Add CJKpunct as standard configuration
    \ifCTEX@punct: 增加判断是否调整中文标点宽度的选项

v0.2b  2004/02/13
    General: 修改缺省的行距
        修改缺省的字号大小

v0.2a  2004/02/11
    \baselinestretch: 增加对行距的设置
    \CTEX@spaceChar: 加快处理速度，改善和 CJKpunct 的兼容性

v0.2  2004/01/16
    General: Add support for CCT
        增加部分修改标题格式设置的选项
        增加修改标题前后空距设置的选项
    \CTEXsetfont: \CTEXfontinfo 命令改为 \CTEXsetfont
    \ziju: 参数的单位由绝对距离改为相对于当前汉字大小的倍数

v0.1f  2003/12/24
    \refname: 修正 article 类中参考文献标题没有使用中文的问题

v0.1e  2003/11/05
    \refstepcounter: 修正 \ref 命令后多出空格的问题

v0.1d  2003/09/27
    \addtocounter: 将对 \setcounter 和 \addtocounter 的修改放到导言的最后以和其他宏包兼容

v0.1c  2003/08/19
    General: 去掉生成的 .out 文件里章的标题前的多余空格

v0.1b  2003/08/17
    \zihao: 删除多余的 \newcount 命令

v0.1a  2003/08/15
    General: 修正 ctex.sty 中无法使用 sub3section 和sub4section 选项的问题

v0.1  2003/08/15
    General: First beta release

v0.0  2003/04/26
    General: Initial version




TODO
====

