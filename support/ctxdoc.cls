%%
%% File ctxdoc.cls
%%
%%     Copyright (C) 2016--2022
%%     CTEX.ORG and any individual authors listed in the documentation.
%%---------------------------------------------------------------------
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
%%     This work has the LPPL maintenance status "maintained".
%%
%%---------------------------------------------------------------------
%%
\NeedsTeXFormat{LaTeX2e}
\RequirePackage{expl3}
\GetIdInfo$Id$
  {ctex documentation (CTEX)}
\ProvidesExplClass{ctxdoc}{\ExplFileDate}{}{\ExplFileDescription}
\ExplSyntaxOff
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{l3doc}}
\PassOptionsToClass{a4paper,full}{l3doc}
\ProcessOptions
\LoadClass{l3doc}
\RequirePackage[UTF8, punct=kaiming, heading, linespread=1.2, sub3section]{ctex}
\ctexset{
  abstractname   = 简介,
  indexname      = 代码索引,
  section/format = \Large\bfseries\raggedright,
  section/name   = {第,节},
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
\RequirePackage{fancyvrb-ex}
\RequirePackage{zref-base}
\geometry{includemp, hmargin={0mm,15mm}, vmargin={25mm,15mm}, footskip=7mm}
\hypersetup{pdfstartview=FitH, bookmarksdepth=subparagraph}
\setcounter{secnumdepth}{4}
\setcounter{tocdepth}{2}
\newcommand*\email{\nolinkurl}
\setmainfont{texgyrepagella}[
  Extension      = .otf,
  UprightFont    = *-regular,
  BoldFont       = *-bold,
  ItalicFont     = *-italic,
  BoldItalicFont = *-bolditalic]
\setsansfont{texgyreheros}[
  Extension      = .otf,
  UprightFont    = *-regular,
  BoldFont       = *-bold,
  ItalicFont     = *-italic,
  BoldItalicFont = *-bolditalic]
\setmonofont{cmun}[
  Extension      = .otf,
  UprightFont    = *btl,
  BoldFont       = *tb,
  ItalicFont     = *bto,
  BoldItalicFont = *tx,
  HyphenChar     = None]
\setmathfont{texgyrepagella-math.otf}
\captionsetup{%
  strut=off, labelsep=quad, labelfont+=bf,
  figureposition = bottom, tableposition = top}
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
\setlist[trivlist]{topsep=\medskipamount}
\renewlist{arguments}{enumerate}{1}
\setlist[arguments]{nolistsep,
  leftmargin=\parindent, labelindent=0pt, labelsep=*,
  label=\texttt{\#\arabic*}\,:}
\newlist{optdesc}{description}{3}
%% 设置间距为 \marginparsep，与 l3doc 一致
\setlist[optdesc]{%
  font=\mdseries\small\ttfamily,align=right,listparindent=\parindent,
  labelsep=\marginparsep,labelindent=-\marginparsep,leftmargin=0pt}
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
\AtEndEnvironment{function}{\ctexsetverticalspacing}
\AfterEndEnvironment{function}{\ctexfixverticalspacing}
\AtBeginEnvironment{syntax}{\linespread{1}\ctexplainps\ctexdisableecglue}
\newrobustcmd\exptarget{%
  \AddLineBeginMainAux{\csgdef{Codedoc@expstar}{}}%
  \Hy@raisedlink{\hypertarget{expstar}{}}}
\newrobustcmd\rexptarget{%
  \AddLineBeginMainAux{\csgdef{Codedoc@rexpstar}{}}%
  \Hy@raisedlink{\hypertarget{rexpstar}{}}}
\newrobustcmd\expstar{\hyperlink{expstar}{$\star$}}
\newrobustcmd\rexpstar{\hyperlink{rexpstar}{\ding{73}}}
\ExplSyntaxOn
\cs_new_protected:Npn \ctexsetverticalspacing
  {
    \par
    \tl_gset:Nx \ctexfixverticalspacing
      { \dim_set:Nn \prevdepth { \dim_use:N \prevdepth } }
    \int_compare:nNnT \lastnodetype = { 11 }
      {
        \tl_gput_right:Nx \ctexfixverticalspacing
          { \exp_not:N \skip_vertical:n { \skip_use:N \lastskip } }
        \unskip
      }
  }
\tl_new:N \ctexfixverticalspacing
\NewDocumentCommand \SideBySideExampleSet { }
  { \prop_put_from_keyval:Nn \l__ctxdoc_side_example_prop }
\prop_new:N \l__ctxdoc_side_example_prop
\prop_set_from_keyval:Nn \l__ctxdoc_side_example_prop
  { frame=single, numbers=left, gobble=5, xrightmargin=.5\linewidth }
\tl_put_left:Nn \SideBySideExample
  {
    \trivlist \item \relax
    \exp_args:Ne \fvset
      { \prop_to_keyval:N \l__ctxdoc_side_example_prop }
  }
\tl_put_right:Nn \endSideBySideExample
  { \endtrivlist }
\ctex_patch_cmd:Nnn \__codedoc_function_typeset_start:
  { \bigskip }
  { \nointerlineskip \addvspace { \bigskipamount } }
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
%% 左侧边注的函数列表采用单倍行距
\ctex_preto_cmd:NnnTF \__codedoc_typeset_functions:
  { }
  { \MacroFont }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\ctex_patch_cmd_once:NnnnTF \__codedoc_macro_init:
  { }
  { \hbox:n }
  { \MacroFont \hbox:n }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\ctex_patch_cmd_once:NnnnTF \__codedoc_macro_dump:
  { }
  { \hbox_unpack_drop:N }
  { \MacroFont \hbox_unpack_drop:N }
  { \iow_term:n { *** ~ SUCCESS ~ *** } }
  { \iow_term:n { *** ~ FAIL ~ *** } }
\cs_set_eq:NN \__codedoc_macro_end_style:n \use_none:n
\cs_set_protected:Npn \__codedoc_macro_typeset_one:nN #1#2
  {
    \vbox_set:Nn \l__codedoc_macro_box
      {
        \MacroFont
        \vbox_unpack_drop:N \l__codedoc_macro_box
        \hbox_set:Nn \l_tmpa_box
          { \__codedoc_print_macroname:nN {#1} #2 }
        \dim_set:Nn \l_tmpa_dim { \marginparwidth - \labelsep }
        \dim_compare:nNnT { \box_wd:N \l_tmpa_box } > \l_tmpa_dim
          {
            \box_resize_to_wd_and_ht:Nnn \l_tmpa_box
              { \l_tmpa_dim }
              { \box_ht:N \l_tmpa_box }
          }
        \hbox_overlap_left:n
          {
            \box_use:N \l_tmpa_box
            \skip_horizontal:n { \marginparsep - \labelsep }
          }
      }
    \int_incr:N \l__codedoc_macro_int
  }
\cs_set_protected:Npn \__codedoc_print_macroname:nN #1#2
  {
    \strut
    \__codedoc_get_hyper_target:eN
      {
        \exp_not:n {#1}
        \bool_if:NT #2 { \tl_to_str:n {TF} }
      }
      \l__codedoc_tmpa_tl
    \cs_if_exist:cTF { r@ \l__codedoc_tmpa_tl }
      { \exp_args:NNo \label@hyperref [ \l__codedoc_tmpa_tl ] }
      { \use:n }
      {
        \tl_set:Nn \l__codedoc_tmpa_tl {#1}
        \tl_replace_all:Non \l__codedoc_tmpa_tl
          { \c_catcode_other_space_tl }
          { \fontspec_visible_space: }
        \__codedoc_macroname_prefix:o \l__codedoc_tmpa_tl
        \__codedoc_macroname_suffix:N #2
      }
  }
\AtBeginEnvironment { syntax }
  {
    \char_set_catcode_active:N \|
    \char_set_active_eq:NN \| \orbar
    \char_set_catcode_active:N \(
    \char_set_active_eq:NN \( \defaultvalaux
  }
%% 不对目录中出现的 \cs 和 \tn 等编索引
\DeclareDocumentCommand \StopSpecialIndexModule { }
  { \cs_set_eq:NN \__codedoc_special_index_module:nnnnN \use_none:nnnnn }
\tl_map_inline:nn { \actualchar \encapchar \levelchar }
  { \exp_args:Nx \DoNotIndex { \bslash \tl_to_str:N #1 } }
\DeclareDocumentCommand \package { o m }
  {
    \exp_args:Nx \href
      {
        http \c_colon_str //www.ctan.org/pkg/
        \IfNoValueTF {#1} { \str_lowercase:n {#2} } {#1}
      }
      { \pkg {#2} }
  }
\DeclareDocumentCommand \GetFileId { m }
  {
    \GetFileInfo {#1}
    \file_get:nnNTF { \c_sys_jobname_str .id }
      { \int_set:Nn \tex_endlinechar:D { -1 } } \l__ctxdoc_tmp_tl
      { \tl_if_empty:NTF \l__ctxdoc_tmp_tl }
      { \use_i:nn }
      { \GetIdInfo $Id$ }
      { \exp_after:wN \GetIdInfo \l__ctxdoc_tmp_tl }
      { \fileinfo }
  }
\cs_new_eq:NN \__ctxdoc_ltx_changes:nnn \changes@
\cs_set_protected:Npn \changes@ #1#2
  {
    \__ctxdoc_save_version_date:nn {#1} {#2}
    \tl_if_empty:nTF {#1}
      { \__ctxdoc_ltx_changes:nnn }
      { \__ctxdoc_version_zfill:wnnn #1 \q_stop }
      {#1} {#2}
  }
\cs_new_protected:Npn \__ctxdoc_version_zfill:wnnn #1#2 \q_stop
  {
    \str_if_eq:nnTF {#1} { v }
      { \__ctxdoc_version_zfill:nnnn {#2} }
      { \__ctxdoc_ltx_changes:nnn }
  }
\cs_new_protected:Npn \__ctxdoc_version_zfill:nnnn #1#2
  {
    \tl_clear:N \l__ctxdoc_tmp_tl
    \int_zero:N \l_tmpa_int
    \seq_set_split:Nnn \l_tmpa_seq { . } {#1}
    \seq_map_function:NN \l_tmpa_seq \__ctxdoc_version_zfill:n
    \int_compare:nNnF \l_tmpa_int > 2
      {
        \tl_put_right:Nx \l__ctxdoc_tmp_tl
          { \prg_replicate:nn { 3 - \l_tmpa_int } { 00000 } }
      }
    \__ctxdoc_ltx_changes:nnn { \l__ctxdoc_tmp_tl \actualchar #2 }
  }
\tl_new:N \l__ctxdoc_tmp_tl
\cs_new_protected:Npn \__ctxdoc_version_zfill:n #1
  {
    \int_incr:N \l_tmpa_int
    \tl_put_right:Nx \l__ctxdoc_tmp_tl
      {
        \prg_replicate:nn
          { \int_max:nn { 0 } { 5 - \tl_count:n {#1} } } { 0 }
        \exp_not:n {#1}
      }
  }
\cs_new_protected:Npn \__ctxdoc_save_version_date:nn #1#2
  {
    \prop_get:NnNTF \g__ctxdoc_version_date_prop {#1} \l__ctxdoc_tmp_tl
      { \exp_after:wN \__ctxdoc_save_version_date:nnnn \l__ctxdoc_tmp_tl {#2} {#1} }
      { \__ctxdoc_save_version_date:nnn {#1} {#2} {#2} }
  }
\cs_new_protected:Npn \__ctxdoc_save_version_date:nnnn #1#2#3#4
  {
    \__ctxdoc_if_date_later:nnTF {#1} {#3}
      { \__ctxdoc_save_version_date:nnn {#4} {#3} {#2} }
      {
        \__ctxdoc_if_date_later:nnT {#3} {#2}
          { \__ctxdoc_save_version_date:nnn {#4} {#1} {#3} }
      }
  }
\prg_new_conditional:Npnn \__ctxdoc_if_date_later:nn #1#2 { TF , T }
  {
    \if_int_compare:w \__ctxdoc_parse_date:w #1 / / / 0 \q_stop >
                      \__ctxdoc_parse_date:w #2 / / / 0 \q_stop \exp_stop_f:
      \prg_return_true: \else: \prg_return_false: \fi:
  }
\cs_new:Npn \__ctxdoc_parse_date:w #1/#2/#3/ #4 \q_stop
  { #1#2#3 }
\cs_new_protected:Npn \__ctxdoc_save_version_date:nnn #1#2#3
  { \prop_gput:Nnn \g__ctxdoc_version_date_prop {#1} { {#2} {#3} } }
\cs_new_protected:Npn \CTEX@versionitem #1 \efill
  {
    \@idxitem
    \prop_get:NnNTF \g__ctxdoc_version_date_prop {#1} \l__ctxdoc_tmp_tl
      { \exp_after:wN \__ctxdoc_version_item:nnn \l__ctxdoc_tmp_tl {#1} }
      { \BOOM }
  }
\cs_new_protected:Npn \__ctxdoc_version_item:nnn #1#2#3
  {
    \noindent
    \Hy@raisedlink { \belowpdfbookmark {#3} { HD.#3 } }
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
\prop_new:N \g__ctxdoc_version_date_prop
\ctex_patch_cmd:Nnn \HDorg@theglossary
  { \let \item \@idxitem }
  { \let \item \CTEX@versionitem }
\ctex_patch_cmd:Nnn \l@section    { 2.5em } { 1.5em }
\ctex_patch_cmd:Nnn \l@subsection { 2.5em } { 1.5em }
\ctex_patch_cmd:Nnn \@wrglossary
  { hdpindex }
  {
    \ifnum \c@HD@hypercount = \z@
      hdpindex
    \else
      hdclindex { \the \c@HD@hypercount }
    \fi
  }
%% 重定义 macrocode 环境的实现，逐行处理
\cs_set_protected_nopar:Npn \xmacro@code
  { \__ctxdoc_marco_code:w }
\cs_set_protected_nopar:Npn \sxmacro@code
  {
    \fontspec_print_visible_spaces:
    \xmacro@code
  }
\cs_new_protected_nopar:Npn \__ctxdoc_marco_code:w
  {
    \ifcodeline@index
      \__ctxdoc_marco_every_par:n { \__ctxdoc_code_line_no: }
    \else:
      \__ctxdoc_marco_every_par:n { }
    \fi:
    \exp_args:Nx \__ctxdoc_make_finish_tag:n { \@currenvir }
    \__ctxdoc_verbatim_start:w
  }
\cs_new_protected:Npn \__ctxdoc_marco_every_par:n #1
  {
    \everypar
      {
        \everypar {#1}
        \if@inlabel
          \global \@inlabelfalse
          \@noparlistfalse
          \unless \ifvoid \CTEX@labelbox
            \llap { \box \CTEX@labelbox \hskip \leftskip }
          \fi
        \fi
        #1
      }
  }
\ctex_patch_cmd:Nnn \macro@code
  { \if@inlabel \leavevmode \fi }
  {
    \partopsep \z@skip
    \if@inlabel \setbox \CTEX@labelbox \copy \@labels \fi
  }
\newbox \CTEX@labelbox
\group_begin:
  \int_set:Nn \tex_endlinechar:D { -1 }
  \use:n
    {
      \char_set_catcode_active:n { 32 }
      \tl_const:Nn \c__ctxdoc_active_space_tl
    }
    { }
\group_end:
\group_begin:
  \char_set_catcode_active:n { 13 }
  \cs_new_protected:Npx \__ctxdoc_make_finish_tag:n #1
    {
      \tl_set:Nn \exp_not:N \l__ctxdoc_verbatim_finish_tl
        {
          \c_percent_str
          \prg_replicate:nn { 4 }
            { \exp_not:o { \c__ctxdoc_active_space_tl } }
          \exp_not:o { \active@escape@char } end
          \c_left_brace_str #1 \c_right_brace_str
          \exp_not:N ^^M
        }
    }
  \cs_new_protected:Npn \__ctxdoc_verbatim_start:w #1
    {
      \str_if_eq:nnTF {#1} { ^^M }
        { \__ctxdoc_verbatim_read_line:w }
        { \__ctxdoc_verbatim_read_line:w #1 }
    }
  \cs_new_protected:Npn \__ctxdoc_verbatim_read_line:w #1 ^^M
    {
      \tl_set:Nn \l__ctxdoc_verbatim_line_tl { #1 ^^M }
      \tl_if_eq:NNTF \l__ctxdoc_verbatim_line_tl \l__ctxdoc_verbatim_finish_tl
        { \exp_args:Nx \end { \@currenvir } }
        {
          \__ctxdoc_verbatim_process_line:
          \__ctxdoc_verbatim_read_line:w
        }
    }
  \cs_new_protected:Npn \__ctxdoc_swap_cr:
    { \exp_after:wN \__ctxdoc_swap_cr:w \l__ctxdoc_verbatim_line_tl }
  \cs_new_protected:Npn \__ctxdoc_swap_cr:w #1 ^^M
    {
      \group_insert_after:N ^^M
      \tl_set:Nn \l__ctxdoc_verbatim_line_tl {#1}
    }
  \tl_const:Nn \c__ctxdoc_active_cr_tl { ^^M }
\group_end:
\tl_new:N \l__ctxdoc_verbatim_line_tl
\tl_new:N \l__ctxdoc_verbatim_finish_tl
\tl_new:N \g__ctxdoc_verbatim_verb_stop_tl
\cs_new_protected_nopar:Npn \__ctxdoc_process_normal_line:
  {
    \str_if_eq:eeTF
      { \str_head:N \l__ctxdoc_verbatim_line_tl } { \c_percent_str }
      { \__ctxdoc_check_angle:x { \tl_tail:N \l__ctxdoc_verbatim_line_tl } }
      { \__ctxdoc_output_line: }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_process_verb_line:
  {
    \tl_if_eq:NNTF \l__ctxdoc_verbatim_line_tl \g__ctxdoc_verbatim_verb_stop_tl
      {
        \tl_gclear:N \g__ctxdoc_verbatim_verb_stop_tl
        \cs_gset_eq:NN \__ctxdoc_verbatim_process_line: \__ctxdoc_process_normal_line:
        \__ctxdoc_output_module:nn
          { \color { verb@guard } }
          {
            \__ctxdoc_swap_cr:
            \__ctxdoc_module_pop:n { \l__ctxdoc_verbatim_line_tl }
          }
      }
      { \tl_use:N \l__ctxdoc_verbatim_line_tl }
  }
\cs_new_eq:NN \__ctxdoc_verbatim_process_line: \__ctxdoc_process_normal_line:
\DeclareDocumentCommand \CheckModules { }
  { \cs_set_eq:NN \__ctxdoc_verbatim_process_line: \__ctxdoc_process_normal_line: }
\DeclareDocumentCommand \DontCheckModules { }
  { \cs_set_eq:NN \__ctxdoc_verbatim_process_line: \__ctxdoc_output_line: }
\cs_new_protected:Npn \__ctxdoc_check_angle:n #1
  {
     \str_if_eq:eeTF { \str_head:n {#1} } { < }
      { \__ctxdoc_check_module:x { \tl_tail:n {#1} } }
      { \__ctxdoc_output_percent_line: }
  }
\cs_generate_variant:Nn \__ctxdoc_check_angle:n { x }
\cs_new_protected:Npn \__ctxdoc_check_module:n #1
  {
    \exp_args:Nx \str_case:nnF { \str_head:n {#1} }
      {
        { * } { \__ctxdoc_module_star:w }
        { / } { \__ctxdoc_module_slash:w }
        { @ } { \__ctxdoc_module_at:w }
        { < } { \__ctxdoc_module_verb:w }
      }
      { \__ctxdoc_module_pm:w }
    #1 \q_stop
  }
\cs_generate_variant:Nn \__ctxdoc_check_module:n { x }
\group_begin:
  \char_set_catcode_active:N \>
  \cs_new_protected:Npn \__ctxdoc_module_star:w #1 > #2 \q_stop
    {
      \__ctxdoc_output_module:nn
        { \__ctxdoc_star_color: }
        { \__ctxdoc_module_push:n { \__ctxdoc_module_angle:n {#1} } }
      \__ctxdoc_output_line:n {#2}
      \__ctxdoc_star_format:
    }
  \cs_new_protected:Npn \__ctxdoc_module_slash:w #1 > #2 \q_stop
    {
      \__ctxdoc_output_module:nn
        { \__ctxdoc_slash_color: }
        { \__ctxdoc_module_pop:n { \__ctxdoc_module_angle:n {#1} } }
      \__ctxdoc_output_line:n {#2}
      \__ctxdoc_slash_format:
    }
  \cs_new_protected:Npn \__ctxdoc_module_at:w @ @ = #1 > #2 \q_stop
    {
      \__ctxdoc_output_module:nn
        { \color { at@guard } }
        { \__ctxdoc_module_angle:n { @ @ = #1 } }
      \tl_gset:Nn \g__codedoc_module_name_tl {#1}
      \__ctxdoc_output_line:n {#2}
    }
  \cs_new_protected:Npn \__ctxdoc_module_pm:w #1 > #2 \q_stop
    {
      \tex_noindent:D
      \hbox_overlap_left:n
        {
          \__ctxdoc_output_module:nn
            { \__ctxdoc_pm_color: }
            { \__ctxdoc_module_angle:n {#1} }
          \skip_horizontal:n { \leftskip + \smallskipamount }
        }
      \group_begin:
        \__ctxdoc_pm_format:
        \__ctxdoc_output_line:n {#2}
      \group_end:
    }
  \cs_new_protected:Npn \__ctxdoc_module_verb:w #1 \q_stop
    {
      \cs_gset_eq:NN \__ctxdoc_verbatim_process_line: \__ctxdoc_process_verb_line:
      \tl_gset:Nx \g__ctxdoc_verbatim_verb_stop_tl
        { \c_percent_str \tl_tail:n {#1} }
      \__ctxdoc_output_module:nn
        { \color { verb@guard } }
        {
          \__ctxdoc_swap_cr:
          \__ctxdoc_module_push:n { \l__ctxdoc_verbatim_line_tl }
        }
    }
\group_end:
\cs_new_protected_nopar:Npn \__ctxdoc_output_line:
  {
    \tex_noindent:D
    \__ctxdoc_replace_at_at:N \l__ctxdoc_verbatim_line_tl
    \tl_use:N \l__ctxdoc_verbatim_line_tl
  }
\cs_new_protected:Npn \__ctxdoc_replace_at_at:N #1
  {
    \tl_if_empty:NF \g__codedoc_module_name_tl
      {
        \exp_args:NNo \__ctxdoc_replace_at_at_aux:Nn
          #1 \g__codedoc_module_name_tl
      }
  }
\cs_new_protected:Npx \__ctxdoc_replace_at_at_aux:Nn #1#2
  {
    \tl_replace_all:Nnn #1 { \token_to_str:N @ } { @ }
    \tl_replace_all:Nnn #1 { \token_to_str:N _ } { _ }
    \tl_replace_all:Nnn #1 { @ @ @ @ } { \token_to_str:N a a }
    \tl_replace_all:Nnn #1 { _ _ @ @ } { _ _ #2 }
    \tl_replace_all:Nnn #1 {   _ @ @ } { _ _ #2 }
    \tl_replace_all:Nnn #1 {     @ @ } { _ _ #2 }
    \tl_replace_all:Nnn #1 { \token_to_str:N a a } { @ @ }
  }
\cs_new_protected:Npn \__ctxdoc_output_line:n #1
  {
    \tl_set:Nn \l__ctxdoc_verbatim_line_tl {#1}
    \tl_if_eq:NNTF \l__ctxdoc_verbatim_line_tl \c__ctxdoc_active_cr_tl
      { \tl_use:N \l__ctxdoc_verbatim_line_tl }
      {
        \str_if_eq:eeTF
          { \str_head:N \l__ctxdoc_verbatim_line_tl }
          { \c_percent_str }
          { \__ctxdoc_output_percent_line: }
          { \__ctxdoc_output_line: }
      }
  }
\cs_new_protected:Npn \__ctxdoc_output_percent_line:
  {
    \tex_noindent:D
    \group_begin:
      \color { code@gray }
      \__ctxdoc_swap_cr:
      \str_if_eq:eeTF { \f@shape } { \updefault }
        { \slshape }
        { \upshape }
      \__ctxdoc_output_line:
    \group_end:
  }
\cs_new_protected_nopar:Npn \__ctxdoc_module_push:n
  { \exp_args:No \__ctxdoc_module_push_aux:nn { \int_use:N \c@HD@hypercount } }
\cs_new_protected:Npn \__ctxdoc_module_push_aux:nn #1
  {
    \seq_gpush:Nn \g__ctxdoc_module_dest_seq {#1}
    \hypersetup { hidelinks }
    \exp_args:Nx \hdclindex
      { \zref@extractdefault { HD.#1 } { guard@end } { 1 } } { }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_module_pop:n
  {
    \seq_gpop:NNTF \g__ctxdoc_module_dest_seq \l__ctxdoc_tmp_tl
      { \exp_args:No \__ctxdoc_module_pop_aux:nn { \l__ctxdoc_tmp_tl } }
      { \BOOM \use:n }
  }
\cs_new_protected:Npn \__ctxdoc_module_pop_aux:nn #1
  {
    \zref@labelbylist { HD.#1 } { ctxdoc }
    \hypersetup { hidelinks }
    \hdclindex {#1} { }
  }
\seq_new:N \g__ctxdoc_module_dest_seq
\zref@newlist { ctxdoc }
\zref@newprop { guard@end } [ 1 ]
  { \int_eval:n { \c@HD@hypercount - 1 } }
\zref@addprop { ctxdoc } { guard@end }
\cs_new_protected_nopar:Npn \__ctxdoc_star_format:
  {
    \seq_gpush:No \g__ctxdoc_slash_format_seq { \macro@font }
    \seq_gpop:NNF \g__ctxdoc_star_format_seq \l__ctxdoc_format_tl
      { \__ctxdoc_pop_format: }
    \__ctxdoc_select_format:
  }
\cs_new_protected_nopar:Npn \__ctxdoc_slash_format:
  {
    \seq_gpop:NNTF \g__ctxdoc_slash_format_seq \l__ctxdoc_format_tl
      {
        \seq_gpush:No \g__ctxdoc_star_format_seq { \macro@font }
        \__ctxdoc_select_format:
      }
      { \BOOM }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_pm_format:
  {
    \seq_get:NNF \g__ctxdoc_star_format_seq \l__ctxdoc_format_tl
      {
        \__ctxdoc_pop_format:
        \seq_gpush:No \g__ctxdoc_star_format_seq { \l__ctxdoc_format_tl }
      }
    \cs_if_eq:NNF \macro@font \l__ctxdoc_format_tl
      { \l__ctxdoc_format_tl }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_pop_format:
  {
    \seq_gpop_left:NN \g__ctxdoc_format_seq \l__ctxdoc_format_tl
    \seq_gput_right:No \g__ctxdoc_format_seq { \l__ctxdoc_format_tl }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_select_format:
  {
    \cs_if_eq:NNF \macro@font \l__ctxdoc_format_tl
      {
        \cs_gset_eq:NN \macro@font \l__ctxdoc_format_tl
        \macro@font
      }
  }
\tl_new:N \l__ctxdoc_format_tl
\seq_new:N \g__ctxdoc_format_seq
\seq_new:N \g__ctxdoc_star_format_seq
\seq_new:N \g__ctxdoc_slash_format_seq
\seq_gput_right:Nn \g__ctxdoc_format_seq { \MacroFont }
\seq_gput_right:Nn \g__ctxdoc_format_seq { \AltMacroFont }
\cs_set_protected:Npn \MacroFont
  {
    \linespread { 1 }
    \small
    \fontseries { \mddefault }
    \fontshape  { \updefault }
    \ttfamily
    \ctexdocverbaddon
  }
\cs_set_protected:Npn \AltMacroFont
  {
    \linespread { 1 }
    \small
    \fontseries { \mddefault }
    \fontshape  { \sldefault }
    \ttfamily
    \ctexdocverbaddon
  }
\AtBeginDocument
  {
    \tl_gset:Nx \macro@font
      { \seq_item:Nn \g__ctxdoc_format_seq { 1 } }
  }
\cs_new_protected:Npn \__ctxdoc_output_module:nn #1#2
  {
    \tex_noindent:D
    \group_begin:
      #1
      \footnotesize \normalfont \sffamily #2
    \group_end:
  }
\cs_new_protected_nopar:Npn \__ctxdoc_star_color:
  {
    \seq_gpop:NNTF \g__ctxdoc_star_color_seq \current@color
      { \set@color }
      { \__ctxdoc_select_color: }
    \seq_gpush:No \g__ctxdoc_slash_color_seq { \current@color }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_slash_color:
  {
    \seq_gpop:NNTF \g__ctxdoc_slash_color_seq \current@color
      {
        \set@color
        \seq_gpush:No \g__ctxdoc_star_color_seq { \current@color }
      }
      { \BOOM }
  }
\cs_new_protected_nopar:Npn \__ctxdoc_pm_color:
  {
    \seq_get:NNTF \g__ctxdoc_star_color_seq \current@color
      { \set@color }
      {
        \__ctxdoc_select_color:
        \seq_gpush:No \g__ctxdoc_star_color_seq { \current@color }
      }
  }
\seq_new:N \g__ctxdoc_star_color_seq
\seq_new:N \g__ctxdoc_slash_color_seq
\cs_new_protected_nopar:Npn \__ctxdoc_select_color:
  { \color { guard@series!!+ } }
\definecolorseries { guard@series }
  { cmyk } { last } { blue } { purple }
\resetcolorseries [ 3 ] { guard@series }
\definecolor { verb@guard } { rgb }  { 0.5  , 0.5 , 0 }
\definecolor { at@guard }   { rgb }  { 0.5  , 0   , 0.5 }
\definecolor { code@gray }  { gray } { 0.5 }
\cs_new_protected:Npn \__ctxdoc_module_angle:n #1
  { \textlangle #1 \textrangle }
\cs_new_protected_nopar:Npn \__ctxdoc_code_line_no:
  {
    \int_gincr:N \c@CodelineNo
    \hbox_overlap_left:n
      {
        \hbox_to_wd:nn
          { \MacroIndent }
          {
            \HD@target
            \tex_hss:D
            \__ctxdoc_code_line_no_style:
            \theCodelineNo \enspace
          }
        \tex_kern:D \@totalleftmargin
      }
  }
\tl_set:Nn \theCodelineNo
  { \arabic { CodelineNo } }
\cs_new_protected_nopar:Npn \__ctxdoc_code_line_no_style:
  { \color { code@gray } \normalfont \sffamily \tiny }
\cs_set_protected:Npn \HD@SetMacroIndent #1
  {
    \group_begin:
      \settowidth \MacroIndent
        {
          \__ctxdoc_code_line_no_style:
          \prg_replicate:nn { \tl_count:n {#1} } { 0 }
          \enspace
        }
      \dim_gset_eq:NN \MacroIndent \MacroIndent
    \group_end:
  }
\ExplSyntaxOff
\AtBeginDocument{\addtocontents{toc}{\StopSpecialIndexModule}}
\pdfstringdefDisableCommands{%
  \let\path\meta
  \let\opt\@firstofone}
% full expansion of \MakeUppercase is changed in LaTeX2e 2022-11-01,
% see latex3/latex2e repo, commit 7447e931820114aa459e66b1a7937cdc9aebb0f4
\ifcsdef{MakeUppercase\space\space\space}
  {\preto\@thehead
    {\protected\long\csdef{MakeUppercase\space\space\space}[#1]#2{{#2}}}}
  {\preto\@thehead
    {\protected\long\csdef{MakeUppercase\space}#1{{#1}}}}
\def\orbar{\textup{\textbar}}
\def\defaultval#1{\textbf{\textup{#1}}}
\def\defaultvalaux#1){\defaultval{#1}}
\def\TF{true\orbar false}
\def\TTF{\defaultval{true}\orbar false}
\def\TFF{true\orbar\defaultval{false}}
\protected\def\opt{\texttt}
\def\TeX{\hologo{TeX}}
\def\pdfTeX{\hologo{pdfTeX}}
\def\XeTeX{\hologo{XeTeX}}
\def\XeLaTeX{\hologo{XeLaTeX}}
\def\LuaLaTeX{\hologo{LuaLaTeX}}
\def\pdfLaTeX{\hologo{pdfLaTeX}}
\def\LaTeX{\hologo{LaTeX}}
\def\LaTeXe{\hologo{LaTeX2e}}
\def\LaTeXiii{\hologo{LaTeX3}}
\def\dvipdfmx{\hologo{DVIPDFMx}}
\def\TeXLive{\hologo{TeXLive}}
\def\MiKTeX{\hologo{MiKTeX}}
\def\pTeX{\hologo{pTeX}}
\def\ApTeX{\hologo{ApTeX}}
\def\upTeX{\hologo{upTeX}}
\def\ApLaTeX{\hologo{ApLaTeX}}
\def\upLaTeX{\hologo{upLaTeX}}
\def\HoLogo@pTeX#1{p\kern -.15em \hologo{TeX}}
\def\HoLogo@pLaTeX#1{p\kern -.05em \hologo{LaTeX}}
\def\HoLogo@ApTeX#1{A\kern -.05em \hologo{pTeX}}
\def\HoLogo@upTeX#1{u\kern -.05em \hologo{pTeX}}
\def\HoLogo@ApLaTeX#1{A\kern -.05em \hologo{pLaTeX}}
\def\HoLogo@upLaTeX#1{u\kern -.05em \hologo{pLaTeX}}
\def\HoLogoBkm@pTeX#1{p\hologo{TeX}}
\def\HoLogoBkm@pLaTeX#1{p\hologo{LaTeX}}
\def\HoLogoBkm@ApTeX#1{A\hologo{pTeX}}
\def\HoLogoBkm@upTeX#1{u\hologo{pTeX}}
\def\HoLogoBkm@ApLaTeX#1{A\hologo{pLaTeX}}
\def\HoLogoBkm@upLaTeX#1{u\hologo{pLaTeX}}
\def\HoLogo@TeXLive#1{\TeX\ Live}
\def\HoLogo@DVIPDFMx#1{DVIPDFM\ensuremath{x}}
\def\bashcmd{\texttt}
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
\appto\GlossaryParms{%
  \raggedcolumns
  \let\Hy@writebookmark\HDorg@writebookmark
  \def\@idxitem{\par\hangindent 2em }%
  \def\subitem{\@idxitem\hspace*{1em}}%
  \def\subsubitem{\@idxitem\hspace*{2em}}}
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
%% End of file ctxdoc.cls.
