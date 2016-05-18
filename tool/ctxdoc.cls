%%
%% This is file `ctxdoc.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% ctex.dtx  (with options: `ctxdoc')
%% 
%%     Copyright (C) 2003--2016
%%     CTEX.ORG and any individual authors listed in the documentation.
%% ------------------------------------------------------------------------------
%% 
%%     This work may be distributed and/or modified under the
%%     conditions of the LaTeX Project Public License, either
%%     version 1.3c of this license or (at your option) any later
%%     version. This version of this license is in
%%        http://www.latex-project.org/lppl/lppl-1-3c.txt
%%     and the latest version of this license is in
%%        http://www.latex-project.org/lppl.txt
%%     and version 1.3 or later is part of all distributions of
%%     LaTeX version 2005/12/01 or later.
%% 
%%     This work has the LPPL maintenance status `maintained'.
%% 
%%     The Current Maintainers of this work are Leo Liu, Qing Lee and Liam Huang.
%% 
%% ------------------------------------------------------------------------------
%% 
\NeedsTeXFormat{LaTeX2e}
\RequirePackage{expl3}
\GetIdInfo$Id: ctex.dtx e942124 2016-05-18 19:46:02 +0800 Qing Lee <sobenlee@gmail.com> $
  {ctex documentation (CTEX)}
\ProvidesExplClass{ctxdoc}
  {\ExplFileDate}{2.4.2}{\ExplFileDescription}
\ExplSyntaxOff
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{l3doc}}
\PassOptionsToClass{a4paper,full}{l3doc}
\ProcessOptions
\@namedef{ver@thumbpdf.sty}{9999/99/99}
\LoadClass{l3doc}
\RequirePackage[UTF8, punct = kaiming, heading, fontset = none,
  linespread = 1.2, sub3section]{ctex}
\ifxetex
  \xeCJKsetup{AutoFakeBold=false}
\fi
\ctexset{
  fontset,
  abstractname   = 简介,
  indexname      = 代码索引,
  section        = {
    format = \Large\bfseries\raggedright,
    name   = {第,节},
  },
}
\RequirePackage[toc]{multitoc}
\RequirePackage{geometry}
\RequirePackage{tabularx}
\RequirePackage{makecell}
\RequirePackage{threeparttable}
\RequirePackage{siunitx}
\RequirePackage{unicode-math}
\RequirePackage{xcolor}
\RequirePackage{caption}
\RequirePackage{fvrb-ex}
\geometry{includemp,hmargin={0mm,15mm},vmargin={25mm,15mm},footskip=7mm}
\hypersetup{pdfstartview=FitH,bookmarksdepth=subparagraph}
\setcounter{secnumdepth}{4}
\setcounter{tocdepth}{2}
\newcommand*\email{\nolinkurl}
\setmainfont{TeX Gyre Pagella}
\setsansfont{TeX Gyre Heros}
\setmonofont[
  UprightFont=* Light, BoldFont=* Bold,
  SlantedFont=* Light Oblique]{CMU Typewriter Text}
\setmathfont{texgyrepagella-math.otf}
\captionsetup{strut=off, labelsep=quad, labelfont+=bf}
%% <--- http://tex.stackexchange.com/a/40896
\patchcmd{\@addtocurcol}%
    {\vskip \intextsep}%
    {\edef\save@first@penalty{\the\lastpenalty}\unpenalty
     \ifnum \lastpenalty = \@M  % hopefully the OR penalty
        \unpenalty
     \else
        \penalty \save@first@penalty \relax % put it back
     \fi
      \ifnum\outputpenalty <-\@Mii
                         \addvspace\intextsep
                         \vskip\parskip
      \else
                         \addvspace\intextsep
      \fi}%
    {\typeout{*** SUCCESS ***}}{\typeout{*** FAIL ***}}
\patchcmd{\@addtocurcol}%
    {\vskip\intextsep \ifnum\outputpenalty <-\@Mii \vskip -\parskip\fi}%
    {\ifnum\outputpenalty <-\@Mii
       \aftergroup\vskip\aftergroup\intextsep
       \aftergroup\nointerlineskip
     \else
       \vskip\intextsep
     \fi}%
    {\typeout{*** SUCCESS ***}}{\typeout{*** FAIL ***}}
\patchcmd{\@getpen}{\@M}{\@Mi}
  {\typeout{*** SUCCESS ***}}{\typeout{*** FAIL ***}}
%% --->
%% 不对代码实现的 \section 以下标题编目录。
\AtBeginEnvironment{implementation}{%
  \ifnum\value{tocdepth}>\@ne
    \addtocontents{toc}{\protect\value{tocdepth}=1\relax}%
  \fi}
\ifxetex
  \let\ctexdocverbaddon\xeCJKVerbAddon
  \def\ctexdisableecglue{\xeCJKsetup{CJKecglue}}
  \def\ctexplainps{\xeCJKsetup{PunctStyle=plain}}
  \appto\meta@font@select{\ifinner\ctexdisableecglue\fi}
\else
  \let\ctexdocverbaddon\relax
  \let\ctexplainps\relax
  \def\ctexdisableecglue{\ltjsetparameter{autoxspacing=false}}
  \appto\meta@font@select{\ctexdisableecglue}
\fi
\setlist{noitemsep,topsep=\smallskipamount}
\setlist[1]{labelindent=\parindent}
\setlist[enumerate]{leftmargin=*}
\setlist[itemize]{leftmargin=*}
\newlist{optdesc}{description}{3}
%% 设置间距为 \marginparsep，与 l3doc 一致
\setlist[optdesc]{%
  font=\mdseries\small\ttfamily,align=right,listparindent=\parindent,
  labelsep=\marginparsep,labelindent=-\marginparsep,leftmargin=*}
%% 重新定义 threeparttable 包的 tablenotes 环境
\renewlist{tablenotes}{description}{1}
\setlist[tablenotes]{%
  format=\normalfont\tnote@item,align=right,listparindent=\parindent,
  labelindent=\tabcolsep,leftmargin=*,rightmargin=\tabcolsep,
  after=\@noparlisttrue}
\AtBeginEnvironment{tablenotes}{%
  \setlength\parindent{2\ccwd}%
  \normalfont\footnotesize}
\AtBeginEnvironment{threeparttable}{%
  \stepcounter{tpt@id}%
  \edef\curr@tpt@id{tpt@\arabic{tpt@id}}}
\newcounter{tpt@id}
\def\tnote@item#1{%
  \Hy@raisedlink{\hyper@anchor{\curr@tpt@id-#1}}#1}
\def\TPTtagStyle#1{\hyperlink{\curr@tpt@id-#1}{#1}}
\fvset{
  fontsize=\small,baselinestretch=1,numbersep=5pt,
  formatcom=\ctexdocverbaddon,
  listparameters=\setlength\topsep{\MacrocodeTopsep}}
\DefineVerbatimEnvironment{frameverb}{Verbatim}{%
  gobble=4,
  frame=single,framesep=8pt,
  listparameters=
    \setlength\topsep{\medskipamount}%
    \appto\FV@EndList{\nointerlineskip}}
\DefineVerbatimEnvironment{ctexexam}{Verbatim}{%
  gobble=4,
  frame=single,framesep=10pt,
  label=\rule{0pt}{12pt}\textnormal{\bfseries 例 \arabic{ctexexam}},
  listparameters=
    \setlength\topsep{\bigskipamount}%
    \refstepcounter{ctexexam}\ctexexamlabelref
    \appto\FV@EndList{\nointerlineskip}}
\define@key{FV}{labelref}{\def\ctexexamlabelref{\label{#1}}}
\let\ctexexamlabelref\empty
\newcounter{ctexexam}
\BeforeBeginEnvironment{function}{\par\nointerlineskip}
\AtEndEnvironment{function}{%
  \par\xdef\ctexfixprevdepth{\prevdepth=\the\prevdepth\space}}
\AfterEndEnvironment{function}{\ctexfixprevdepth}
\AtBeginEnvironment{syntax}{\linespread{1}\ctexplainps\ctexdisableecglue}
\BeforeBeginEnvironment{SideBySideExample}{\par\addvspace{\medskipamount}}
\preto\MacroFont{\linespread{1}}
\appto\MacroFont{\hyphenchar\font\m@ne\ctexdocverbaddon}
\preto\AltMacroFont{\linespread{1}}
\appto\AltMacroFont{\hyphenchar\font\m@ne\ctexdocverbaddon}
\def\Module#1{\mbox{%
  \color{purple}\footnotesize\normalfont\sffamily\textlangle#1\textrangle}}
\newcommand*\exptarget{\Hy@raisedlink{\hypertarget{expstar}{}}}
\newcommand*\rexptarget{\Hy@raisedlink{\hypertarget{rexpstar}{}}}
\newcommand*\expstar{\hyperlink{expstar}{$\star$}}
\newcommand*\rexpstar{\hyperlink{rexpstar}{\ding{73}}}
\ExplSyntaxOn
%% l3doc 会设置列表环境中 \listparindent=\z@，我们在这里恢复它。
\cs_set_eq:NN \list \__codedoc_oldlist:nn
\cs_new_nopar:Npn \zihaopt #1
  {
    \exp_last_unbraced:Nf \tl_head:w
      { \prop_item:Nn \c__ctex_font_size_prop {#1} } { } \q_stop
  }
%% 抑制首段的 \parskip
\ctex_patch_cmd_once:NnnnTF \__codedoc_function_descr_start:w
  { }
  { \noindent }
  { \skip_vertical:n { -\parskip } \noindent }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
%% l3doc 会在 function 环境的 syntax 和 descr 盒子中间加上 \medskipamount 的距离。
%% 但是若 syntax 盒子为空（未使用 syntax 环境），就会显得不好看。
%% 此时我们通过将 \medskipamount 设置为零来修正。若盒子非空，则将 \parskip 还回去。
\ctex_preto_cmd:NnnTF \__codedoc_function_assemble:
  { }
  { \ctex_doc_fix_yoffset: }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\cs_new_protected_nopar:Npn \ctex_doc_fix_yoffset:
  {
    \box_if_empty:NTF \g__codedoc_syntax_box
      { \skip_zero:N \medskipamount }
      { \skip_add:Nn \medskipamount { \parskip } }
  }
%% 用 \vtop 让函数名字和语法盒子首行对齐
\ctex_patch_cmd_once:NnnnTF \__codedoc_syntax:w
  { }
  { { minipage } { \l__codedoc_syntax_dim } }
  { { minipage } [t] { \l__codedoc_syntax_dim } }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
%% 左侧边注的函数列表采用单倍行距
\ctex_preto_cmd:NnnTF \__codedoc_typeset_names:
  { }
  { \linespread { 1 } }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\ctex_patch_cmd_once:NnnnTF \__codedoc_macro_typeset_one:n
  { }
  { \vbox_unpack_clear:N }
  { \linespread { 1 } \selectfont \vbox_unpack_clear:N }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
%% 不重复使用 \HD@target，避免索引出现重复页码
\cs_set_protected:Npn \__codedoc_special_index_aux:nnnnn #1#2#3#4#5
  {
    \__codedoc_special_index_set:Nn \l__codedoc_index_escaped_macro_tl {#2}
    \str_if_eq:onTF { \@currenvir } { macrocode }
      { \codeline@wrindex }
      {
        \HD@target
        \index
      }
      {
        \tl_if_empty:nF { #3 #4 }
          { #3 \actualchar #4 \levelchar }
        #1
        \actualchar
        {
          \token_to_str:N \verbatim@font \c_space_tl
          \l__codedoc_index_escaped_macro_tl
        }
        \encapchar
        hdclindex{\the\c@HD@hypercount}{#5}
      }
  }
\DeclareDocumentCommand \cs { O{} m }
  { \__codedoc_cmd_aux:no {#1} { \c__codedoc_backslash_tl #2 } }
\DeclareDocumentCommand \tn { O{} m }
  {
    \__codedoc_cmd_aux:no
      { index = TeX , replace = false , #1 }
      { \c__codedoc_backslash_tl #2 }
  }
\DeclareDocumentCommand \meta { +m }
  { \__codedoc_meta_aux:n {#1} }
\DeclareExpandableDocumentCommand \bookmarkcstn { O{} m }
  { \textbackslash \tl_to_str:n {#2} }
\cs_new:Npn \bookmarkmeta #1 { < \tl_to_str:n {#1} > }
\cs_generate_variant:Nn \__codedoc_cmd_aux:nn { no }
\AtBeginEnvironment { syntax }
  {
    \char_set_catcode_active:N \|
    \char_set_active_eq:NN \| \orbar
    \char_set_catcode_active:N \(
    \char_set_active_eq:NN \( \defaultvalaux
  }
%% 不对目录中出现的 \cs 和 \tn 等编索引
\DeclareDocumentCommand \StopSpecialIndexModule { }
  { \cs_set_eq:NN \__codedoc_special_index_module:nnnn \use_none:nnnn }
\tl_map_inline:nn { \actualchar \encapchar \levelchar }
  { \exp_args:Nx \DoNotIndex { \bslash \tl_to_str:N #1 } }
\DeclareDocumentCommand \package { o m }
  {
    \exp_args:Nx \href
      {
        http \c_colon_str //www.ctan.org/pkg/
        \IfNoValueTF {#1} { \str_fold_case:n {#2} } {#1}
      }
      { \pkg {#2} }
  }
\DeclareDocumentCommand \GetFileId { m }
  {
    \GetFileInfo {#1}
    \ior_open:NnTF \g__ctex_doc_ior { \c_sys_jobname_str .id }
      {
        \ior_get:NN \g__ctex_doc_ior \l__ctex_tmp_tl
        \ior_close:N \g__ctex_doc_ior
        \exp_after:wN \GetIdInfo \l__ctex_tmp_tl
      }
      { \GetIdInfo $Id$ }
      { \fileinfo }
  }
\ior_new:N \g__ctex_doc_ior
\cs_new_protected:Npn \CTEX@saveversiondate #1#2
  {
    \prop_get:NnNTF \g__ctex_version_date_prop {#1} \l__ctex_tmp_tl
      { \exp_after:wN \__ctex_save_version_date:nnnn \l__ctex_tmp_tl {#2} {#1} }
      { \__ctex_save_version_date:nnn {#1} {#2} {#2} }
  }
\cs_new_protected:Npn \__ctex_save_version_date:nnnn #1#2#3#4
  {
    \__ctex_if_date_later:nnTF {#1} {#3}
      { \__ctex_save_version_date:nnn {#4} {#3} {#2} }
      {
        \__ctex_if_date_later:nnT {#3} {#2}
          { \__ctex_save_version_date:nnn {#4} {#1} {#3} }
      }
  }
\prg_new_conditional:Npnn \__ctex_if_date_later:nn #1#2 { TF , T }
  {
    \if_int_compare:w \__ctex_parse_date:w #1 / / / 0 \q_stop >
                      \__ctex_parse_date:w #2 / / / 0 \q_stop \exp_stop_f:
      \prg_return_true: \else: \prg_return_false: \fi:
  }
\cs_new:Npn \__ctex_parse_date:w #1/#2/#3/ #4 \q_stop
  { #1#2#3 }
\cs_new_protected:Npn \__ctex_save_version_date:nnn #1#2#3
  { \prop_gput:Nnn \g__ctex_version_date_prop {#1} { {#2} {#3} } }
\cs_new_protected:Npn \CTEX@versionitem #1 \efill
  {
    \@idxitem
    \prop_get:NnNTF \g__ctex_version_date_prop {#1} \l__ctex_tmp_tl
      { \exp_after:wN \__ctex_version_item:nnn \l__ctex_tmp_tl {#1} }
      { \BOOM }
  }
\cs_new_protected:Npn \__ctex_version_item:nnn #1#2#3
  {
    \textbf {#3} \hfill
    \hbox:n
      {
        \footnotesize
        \str_if_eq:nnTF {#1} {#2}
          { ( #1 ) }
          { ( #1 ~ -- ~ #2 ) }
      }
    \par \nopagebreak
  }
\prop_new:N \g__ctex_version_date_prop
\ctex_preto_cmd:NnnTF \changes@
  { \ExplSyntaxOff }
  { \CTEX@saveversiondate {#1} {#2} }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\ctex_patch_cmd_once:NnnnTF \HDorg@theglossary
  { \ExplSyntaxOff }
  { \let \item \@idxitem }
  { \let \item \CTEX@versionitem }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\ExplSyntaxOff
\AtBeginDocument{\addtocontents{toc}{\StopSpecialIndexModule}}
\pdfstringdefDisableCommands{%
  \let\cs\bookmarkcstn
  \let\tn\bookmarkcstn
  \let\meta\bookmarkmeta
  \let\path\meta
  \let\opt\@firstofone}
\preto\@thehead{\cslet{MakeUppercase\space}{\@iden}}
\def\orbar{\textup{\textbar}}
\def\defaultval#1{\textbf{\textup{#1}}}
\def\defaultvalaux#1){\defaultval{#1}}
\def\TF{true\orbar false}
\def\TTF{\defaultval{true}\orbar false}
\def\TFF{true\orbar\defaultval{false}}
\protected\def\opt{\texttt}
\def\pdfTeX{\hologo{pdfTeX}}
\def\XeTeX{\hologo{XeTeX}}
\def\XeLaTeX{\hologo{XeLaTeX}}
\def\LuaLaTeX{\hologo{LuaLaTeX}}
\def\pdfLaTeX{\hologo{pdfLaTeX}}
\def\LaTeX{\hologo{LaTeX}}
\def\LaTeXe{\hologo{LaTeX2e}}
\def\LaTeXiii{\hologo{LaTeX3}}
\def\dvipdfmx{DVIPDFM\textit{x}}
\def\TeX{\hologo{TeX}}
\def\ApTeX{Ap\TeX}
\def\ApLaTeX{Ap\LaTeX}
\def\upTeX{up\TeX}
\def\upLaTeX{up\LaTeX}
\def\bashcmd{\texttt}
\def\TeXLive{\TeX\ Live}
\def\MiKTeX{\hologo{MiKTeX}}
\def\BSTACK{\begin{tabular}[t]{@{}l@{}}}
\def\ESTACK{\end{tabular}}
\newenvironment{defaultcapconfig}{%
  \MakePercentComment
  \input{ctex-name-utf8.cfg}%
  \ExplSyntaxOff
  \MakePercentIgnore}{}
\def\ctexkit{\href{https://github.com/CTeX-org/ctex-kit/}{\texttt{ctex-kit}}}
\def\ctexkitrev#1{%
  \href{https://github.com/CTeX-org/ctex-kit/commit/#1}{\texttt{ctex-kit} rev. #1}}
\patchcmd\theCodelineNo{\sffamily\tiny}{\normalfont\sffamily\tiny}{}{}
\appto\GlossaryParms{%
  \def\@idxitem{\par\hangindent 2em }%
  \def\subitem{\@idxitem\hspace*{1em}}%
  \def\subsubitem{\@idxitem\hspace*{2em}}}
\patchcmd\l@section{2.5em}{1.5em}{}{}
\patchcmd\l@subsection{2.5em}{1.5em}{}{}
\patchcmd\changes@{\space}{\lbrack}{}{}
\patchcmd\@wrglossary{hdpindex}{%
  \ifnum\c@HD@hypercount=\z@
    hdpindex%
  \else
    hdclindex{\the\c@HD@hypercount}\fi}{}{}
\def\glossaryname{版本历史}
\GlossaryPrologue{\section{\glossaryname}}
\IndexPrologue{%
  \section{\indexname}
  \textit{意大利体的数字表示描述对应索引项的页码；
  带下划线的数字表示定义对应索引项的代码行号；
  罗马字体的数字表示使用对应索引项的代码行号。}}
\def\IndexLayout{%
  \newgeometry{hmargin=15mm,vmargin={25mm,15mm},footskip=7mm}%
  \setlength\IndexMin{.5\textheight}%
  \ctexset{section/numbering=false}%
  \StopSpecialIndexModule}
\EnableCrossrefs
\CodelineIndex
\RecordChanges
%% 
%%
%% End of file `ctxdoc.cls'.
