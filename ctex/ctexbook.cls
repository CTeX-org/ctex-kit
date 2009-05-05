%%
%% This is file `ctexbook.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% ctex.dtx  (with options: `cls,book')
%% 
%% This is a generated file.
%% 
%% Copyright 2003-2006
%% CTEX.ORG and any individual authors listed elsewhere in this file.
%% 
%% This file was generated from file(s) of the ctex package project.
%% -----------------------------------------------------------------
%% 
%% It may be distributed and/or modified under the
%% conditions of the LaTeX Project Public License, either version 1.2
%% of this license or (at your option) any later version.
%% The latest version of this license is in
%%    http://www.latex-project.org/lppl.txt
%% and version 1.2 or later is part of all distributions of LaTeX
%% version 1999/12/01 or later.
%% 
%% This file may only be distributed together with a copy of original
%% source files. You may however distribute original source files
%% without such generated files. Copying of this file is authorized
%% only if either:
%% (1) you make absolutely no changes to your copy, including name; OR
%% (2) if you do make changes, you first rename it to some other name.
%% 
%% To produce the documentation run the original source files ending
%% with `.dtx' through LaTeX.
%% 
%% \CharacterTable
%%  {Upper-case    \A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z
%%   Lower-case    \a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z
%%   Digits        \0\1\2\3\4\5\6\7\8\9
%%   Exclamation   \!     Double quote  \"     Hash (number) \#
%%   Dollar        \$     Percent       \%     Ampersand     \&
%%   Acute accent  \'     Left paren    \(     Right paren   \)
%%   Asterisk      \*     Plus          \+     Comma         \,
%%   Minus         \-     Point         \.     Solidus       \/
%%   Colon         \:     Semicolon     \;     Less than     \<
%%   Equals        \=     Greater than  \>     Question mark \?
%%   Commercial at \@     Left bracket  \[     Backslash     \\
%%   Right bracket \]     Circumflex    \^     Underscore    \_
%%   Grave accent  \`     Left brace    \{     Vertical bar  \|
%%   Right brace   \}     Tilde         \~}
%%
\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexbook}
  [2007/05/06 v0.8a ctex
   document class]
\newif\ifCTEX@cct \CTEX@cctfalse
\DeclareOption{CCT}{\CTEX@ccttrue}
\newif\ifCTEX@cctfont \CTEX@cctfontfalse
\DeclareOption{CCTfont}{\CTEX@ccttrue\CTEX@cctfonttrue}
\newif\ifCTEX@punct \CTEX@puncttrue
\DeclareOption{punct}{\CTEX@puncttrue}
\DeclareOption{nopunct}{\CTEX@punctfalse}
\newif\ifCTEX@space \CTEX@spacefalse
\DeclareOption{space}{\CTEX@spacetrue}
\DeclareOption{nospace}{\CTEX@spacefalse}
\newif\ifCTEX@caption \CTEX@captiontrue
\DeclareOption{nocap}{\CTEX@captionfalse}
\DeclareOption{cap}{\CTEX@captiontrue}
\newif\ifCTEX@indent \CTEX@indenttrue
\DeclareOption{noindent}{\CTEX@indentfalse}
\DeclareOption{indent}{\CTEX@indenttrue}
\newif\ifCTEX@psfont \CTEX@psfontfalse
\DeclareOption{psfont}{\CTEX@psfonttrue}
\newif\ifCTEX@fancyhdr \CTEX@fancyhdrfalse
\DeclareOption{fancyhdr}{\CTEX@fancyhdrtrue}
\newif\ifCTEX@fntef \CTEX@fnteffalse
\DeclareOption{fntef}{\CTEX@fnteftrue}
\newcounter{CTEX@sectiondepth}
\setcounter{CTEX@sectiondepth}{2}
\DeclareOption{sub3section}{\setcounter{CTEX@sectiondepth}{3}}
\DeclareOption{sub4section}{\setcounter{CTEX@sectiondepth}{4}}
\newif\ifCTEX@sfoursize \CTEX@sfoursizefalse
\DeclareOption{cs4size}{\CTEX@sfoursizetrue\CTEX@fivesizefalse}
\newif\ifCTEX@fivesize \CTEX@fivesizetrue
\DeclareOption{c5size}{\CTEX@fivesizetrue\CTEX@sfoursizefalse}
\DeclareOption{10pt}{%
  \CTEX@sfoursizefalse\CTEX@fivesizefalse%
  \PassOptionsToClass{\CurrentOption}%
    {book}}
\DeclareOption{11pt}{%
  \CTEX@sfoursizefalse\CTEX@fivesizefalse%
  \PassOptionsToClass{\CurrentOption}%
    {book}}
\DeclareOption{12pt}{%
  \CTEX@sfoursizefalse\CTEX@fivesizefalse%
  \PassOptionsToClass{\CurrentOption}%
    {book}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}%
  {book}}
\ProcessOptions
\ifCTEX@sfoursize
  \PassOptionsToClass{12pt}%
    {book}
\fi
\ifCTEX@fivesize
  \PassOptionsToClass{10pt}%
    {book}
\fi
\LoadClass{book}
\RequirePackage{keyval}[1999/03/16]
\ifCTEX@indent
  \RequirePackage{indentfirst}
\fi
\ifCTEX@psfont
  \RequirePackage[T1]{fontenc}
  \RequirePackage{textcomp}
  \RequirePackage{mathptmx}
  \RequirePackage[scaled]{helvet}
  \RequirePackage{courier}
\else
  \RequirePackage{type1cm}
\fi
\ifCTEX@fancyhdr
  \RequirePackage{fancyhdr}
\fi
\DeclareRobustCommand\CTeX{C\kern-.05em\TeX{}}
\newcommand*\CTEX@key{\define@key{CTEX}}
\newcommand*\CTEXoptions[1][]{\setkeys{CTEX}{#1}}
\newcommand*\CTEX@subkey[1]{\define@key{CTEX#1}}
\newcommand*\CTEXsetup[2][]{\setkeys{CTEX#2}{#1}}
\def\CTEX@cls@book{}
\def\ifCTEX@cls#1{%
  \expandafter\ifx\csname CTEX@cls@#1\endcsname\relax
    \expandafter\@secondoftwo
  \else
    \expandafter\@firstoftwo
  \fi}
\def\CTEX@replacecommand#1#2#3{%
  \expandafter\expandafter\expandafter\let\expandafter
    \csname #1#3\expandafter\endcsname
    \csname #2#3\endcsname
  \expandafter\expandafter\expandafter\def\expandafter
    \csname #2#3\expandafter\endcsname
    {\csname #1#3\endcsname}}
\ifCTEX@cct
  \input{ctexcct.clo}
\else
  \input{ctexcjk.clo}
\fi
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.def}{}{%
    \PackageError{ctex}{%
      Can't find ctex.def}{%
      There will be unexpected errors if you continue.}}
  \makeatother}
\ifCTEX@caption
  \AtEndOfPackage{%
    \makeatletter
    \InputIfFileExists{ctexcap.cfg}{}{%
      \PackageError{ctex}{%
        Can't find ctexcap.cfg}{%
        The english captions are used if you continue.}}
    \makeatother}
\fi
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.cfg}{}{%
    \PackageWarning{ctex}{%
      Can't find ctex.cfg}}
  \makeatother}
\newcommand*\CTEXindent{\CTEXsetfont\parindent2\ccwd}
\newcommand*\CTEXnoindent{\parindent\z@}
\ifCTEX@indent
  \AtBeginDocument{\CTEXindent}
\fi
\def\CTEX@spaceChar{\hskip \f@size \p@}
\def\baselinestretch{1.3}
\def\CTEX@fs@eight{5.02}   \def\CTEX@fs@eightskip{6.02}   %°ËºÅ×Ö    5bp
\def\CTEX@fs@seven{5.52}   \def\CTEX@fs@sevenskip{6.62}   %ÆßºÅ×Ö  5.5bp
\def\CTEX@fs@ssix{6.52}    \def\CTEX@fs@ssixskip{7.83}    %Ð¡ÁùºÅ  6.5bp
\def\CTEX@fs@six{7.53}     \def\CTEX@fs@sixskip{9.03}     %ÁùºÅ×Ö  7.5bp
\def\CTEX@fs@sfive{9.03}   \def\CTEX@fs@sfiveskip{10.84}  %Ð¡ÎåºÅ    9bp
\def\CTEX@fs@five{10.54}   \def\CTEX@fs@fiveskip{12.65}   %ÎåºÅ×Ö 10.5bp
\def\CTEX@fs@sfour{12.05}  \def\CTEX@fs@sfourskip{14.45}  %Ð¡ËÄºÅ   12bp
\def\CTEX@fs@four{14.05}   \def\CTEX@fs@fourskip{16.86}   %ËÄºÅ×Ö   14bp
\def\CTEX@fs@sthree{15.06} \def\CTEX@fs@sthreeskip{18.07} %Ð¡ÈýºÅ   15bp
\def\CTEX@fs@three{16.06}  \def\CTEX@fs@threeskip{19.27}  %ÈýºÅ×Ö   16bp
\def\CTEX@fs@stwo{18.07}   \def\CTEX@fs@stwoskip{21.68}   %Ð¡¶þºÅ   18bp
\def\CTEX@fs@two{22.08}    \def\CTEX@fs@twoskip{26.50}    %¶þºÅ×Ö   22bp
\def\CTEX@fs@sone{24.09}   \def\CTEX@fs@soneskip{28.91}   %Ð¡Ò»ºÅ   24bp
\def\CTEX@fs@one{26.10}    \def\CTEX@fs@oneskip{31.32}    %Ò»ºÅ×Ö   26bp
\def\CTEX@fs@szero{36.14}  \def\CTEX@fs@szeroskip{43.36}  %Ð¡³õºÅ   36bp
\def\CTEX@fs@zero{42.16}   \def\CTEX@fs@zeroskip{50.59}   %³õºÅ×Ö   42bp
\DeclareMathSizes{\CTEX@fs@eight}{\CTEX@fs@eight}{5}{5}
\DeclareMathSizes{\CTEX@fs@seven}{\CTEX@fs@seven}{5}{5}
\DeclareMathSizes{\CTEX@fs@ssix}{\CTEX@fs@ssix}{5}{5}
\DeclareMathSizes{\CTEX@fs@six}{\CTEX@fs@six}{5}{5}
\DeclareMathSizes{\CTEX@fs@sfive}{\CTEX@fs@sfive}{6}{5}
\DeclareMathSizes{\CTEX@fs@five}{\CTEX@fs@five}{7}{5}
\DeclareMathSizes{\CTEX@fs@sfour}{\CTEX@fs@sfour}{8}{6}
\DeclareMathSizes{\CTEX@fs@four}
                 {\CTEX@fs@four}{\CTEX@fs@five}{\CTEX@fs@six}
\DeclareMathSizes{\CTEX@fs@sthree}
                 {\CTEX@fs@sthree}{\CTEX@fs@sfour}{\CTEX@fs@sfive}
\DeclareMathSizes{\CTEX@fs@three}
                 {\CTEX@fs@three}{\CTEX@fs@four}{\CTEX@fs@five}
\DeclareMathSizes{\CTEX@fs@stwo}
                 {\CTEX@fs@stwo}{\CTEX@fs@sthree}{\CTEX@fs@sfour}
\DeclareMathSizes{\CTEX@fs@two}
                 {\CTEX@fs@two}{\CTEX@fs@three}{\CTEX@fs@four}
\DeclareMathSizes{\CTEX@fs@sone}
                 {\CTEX@fs@sone}{\CTEX@fs@stwo}{\CTEX@fs@sthree}
\DeclareMathSizes{\CTEX@fs@one}
                 {\CTEX@fs@one}{\CTEX@fs@two}{\CTEX@fs@three}
\DeclareMathSizes{\CTEX@fs@szero}
                 {\CTEX@fs@szero}{\CTEX@fs@sone}{\CTEX@fs@stwo}
\DeclareMathSizes{\CTEX@fs@zero}
                 {\CTEX@fs@zero}{\CTEX@fs@one}{\CTEX@fs@two}
\def\CTEX@zihao{}
\DeclareRobustCommand*\zihao[1]{\def\CTEX@zihao{#1}%
  \ifnum #11<0%
    \@tempcnta=-#1
    \ifcase\@tempcnta%
        \fontsize\CTEX@fs@szero\CTEX@fs@szeroskip%
    \or \fontsize\CTEX@fs@sone\CTEX@fs@soneskip%
    \or \fontsize\CTEX@fs@stwo\CTEX@fs@stwoskip%
    \or \fontsize\CTEX@fs@sthree\CTEX@fs@sthreeskip%
    \or \fontsize\CTEX@fs@sfour\CTEX@fs@sfourskip%
    \or \fontsize\CTEX@fs@sfive\CTEX@fs@sfiveskip%
    \or \fontsize\CTEX@fs@ssix\CTEX@fs@ssixskip%
    \else \PackageError{ctex}{%
            Undefined Chinese font size in command \protect\zihao}{%
            The old font size is used if you continue.}%
    \fi%
  \else%
    \@tempcnta=#1
    \ifcase\@tempcnta%
        \fontsize\CTEX@fs@zero\CTEX@fs@zeroskip%
    \or \fontsize\CTEX@fs@one\CTEX@fs@oneskip%
    \or \fontsize\CTEX@fs@two\CTEX@fs@twoskip%
    \or \fontsize\CTEX@fs@three\CTEX@fs@threeskip%
    \or \fontsize\CTEX@fs@four\CTEX@fs@fourskip%
    \or \fontsize\CTEX@fs@five\CTEX@fs@fiveskip%
    \or \fontsize\CTEX@fs@six\CTEX@fs@sixskip%
    \or \fontsize\CTEX@fs@seven\CTEX@fs@sevenskip%
    \or \fontsize\CTEX@fs@eight\CTEX@fs@eightskip%
    \else \PackageError{ctex}{%
            Undefined Chinese font size in command \protect\zihao}{%
            The old font size is used if you continue.}%
    \fi%
  \fi%
  \selectfont\ignorespaces}
\ifCTEX@sfoursize
  \renewcommand\normalsize{% 12bp
    \@setfontsize\normalsize{\CTEX@fs@sfour}{\CTEX@fs@sfourskip}%
    \abovedisplayskip 12\p@ \@plus3\p@ \@minus7\p@
    \abovedisplayshortskip \z@ \@plus3\p@
    \belowdisplayshortskip 6.5\p@ \@plus3.5\p@ \@minus3\p@
    \belowdisplayskip \abovedisplayskip
    \let\@listi\@listI}
  \normalsize
  \renewcommand\small{% 10.5bp
    \@setfontsize\small{\CTEX@fs@five}{\CTEX@fs@fiveskip}%
    \abovedisplayskip 11\p@ \@plus3\p@ \@minus6\p@
    \abovedisplayshortskip \z@ \@plus3\p@
    \belowdisplayshortskip 6.5\p@ \@plus3.5\p@ \@minus3\p@
    \def\@listi{\leftmargin\leftmargini
                \topsep 9\p@ \@plus3\p@ \@minus5\p@
                \parsep 4.5\p@ \@plus2\p@ \@minus\p@
                \itemsep \parsep}%
    \belowdisplayskip \abovedisplayskip}
  \renewcommand\footnotesize{% 9bp
    \@setfontsize\footnotesize{\CTEX@fs@sfive}{\CTEX@fs@sfiveskip}%
    \abovedisplayskip 10\p@ \@plus2\p@ \@minus5\p@
    \abovedisplayshortskip \z@ \@plus3\p@
    \belowdisplayshortskip 6\p@ \@plus3\p@ \@minus3\p@
    \def\@listi{\leftmargin\leftmargini
                \topsep 6\p@ \@plus2\p@ \@minus2\p@
                \parsep 3\p@ \@plus2\p@ \@minus\p@
                \itemsep \parsep}%
    \belowdisplayskip \abovedisplayskip}
  \renewcommand\scriptsize{% 7.5bp
    \@setfontsize\scriptsize{\CTEX@fs@six}{\CTEX@fs@sixskip}}
  \renewcommand\tiny{% 6.5bp
    \@setfontsize\tiny{\CTEX@fs@ssix}{\CTEX@fs@ssixskip}}
  \renewcommand\large{% 15bp
    \@setfontsize\large{\CTEX@fs@sthree}{\CTEX@fs@sthreeskip}}
  \renewcommand\Large{% 18bp
    \@setfontsize\Large{\CTEX@fs@stwo}{\CTEX@fs@stwoskip}}
  \renewcommand\LARGE{% 22bp
    \@setfontsize\LARGE{\CTEX@fs@two}{\CTEX@fs@twoskip}}
  \renewcommand\huge{% 24bp
    \@setfontsize\huge{\CTEX@fs@sone}{\CTEX@fs@soneskip}}
  \renewcommand\Huge{% 26bp
    \@setfontsize\Huge{\CTEX@fs@one}{\CTEX@fs@oneskip}}
\fi
\ifCTEX@fivesize
  \renewcommand\normalsize{% 10.5bp
    \@setfontsize\normalsize{\CTEX@fs@five}{\CTEX@fs@fiveskip}%
    \abovedisplayskip 10\p@ \@plus2\p@ \@minus5\p@
    \abovedisplayshortskip \z@ \@plus3\p@
    \belowdisplayshortskip 6\p@ \@plus3\p@ \@minus3\p@
    \belowdisplayskip \abovedisplayskip
    \let\@listi\@listI}
  \normalsize
  \renewcommand\small{% 9bp
    \@setfontsize\small{\CTEX@fs@sfive}{\CTEX@fs@sfiveskip}%
    \abovedisplayskip 8.5\p@ \@plus3\p@ \@minus4\p@
    \abovedisplayshortskip \z@ \@plus2\p@
    \belowdisplayshortskip 4\p@ \@plus2\p@ \@minus2\p@
    \def\@listi{\leftmargin\leftmargini
                \topsep 4\p@ \@plus2\p@ \@minus2\p@
                \parsep 2\p@ \@plus\p@ \@minus\p@
                \itemsep \parsep}%
    \belowdisplayskip \abovedisplayskip}
  \renewcommand\footnotesize{% 7.5bp
    \@setfontsize\footnotesize{\CTEX@fs@six}{\CTEX@fs@sixskip}%
    \abovedisplayskip 6\p@ \@plus2\p@ \@minus4\p@
    \abovedisplayshortskip \z@ \@plus\p@
    \belowdisplayshortskip 3\p@ \@plus\p@ \@minus2\p@
    \def\@listi{\leftmargin\leftmargini
                \topsep 3\p@ \@plus\p@ \@minus\p@
                \parsep 2\p@ \@plus\p@ \@minus\p@
                \itemsep \parsep}%
    \belowdisplayskip \abovedisplayskip}
  \renewcommand\scriptsize{% 6.5bp
    \@setfontsize\scriptsize{\CTEX@fs@ssix}{\CTEX@fs@ssixskip}}
  \renewcommand\tiny{% 5.5bp
    \@setfontsize\tiny{\CTEX@fs@seven}{\CTEX@fs@sevenskip}}
  \renewcommand\large{% 12bp
    \@setfontsize\large{\CTEX@fs@sfour}{\CTEX@fs@sfourskip}}
  \renewcommand\Large{% 15bp
    \@setfontsize\Large{\CTEX@fs@sthree}{\CTEX@fs@sthreeskip}}
  \renewcommand\LARGE{% 18bp
    \@setfontsize\LARGE{\CTEX@fs@stwo}{\CTEX@fs@stwoskip}}
  \renewcommand\huge{% 22bp
    \@setfontsize\huge{\CTEX@fs@two}{\CTEX@fs@twoskip}}
  \renewcommand\Huge{% 26bp
    \@setfontsize\Huge{\CTEX@fs@one}{\CTEX@fs@oneskip}}
\fi
\newif\ifCTEX@zero@
\newif\ifCTEX@previous@
\newif\ifCTEX@null@
\newcount\CTEX@q
\newcount\CTEX@r
\def\CTEX@appendstring#1#2{%
  \expandafter\def\expandafter#1\expandafter{#1#2}}
\def\CTEX@appendnumber#1#2{%
  \ifcase #2\relax
    \ifCTEX@null@
      \CTEX@appendstring{#1}{\CTEX@null}%
    \else
      \CTEX@appendstring{#1}{\CTEX@zero}%
    \fi
  \or \CTEX@appendstring{#1}{\CTEX@one}%
  \or \CTEX@appendstring{#1}{\CTEX@two}%
  \or \CTEX@appendstring{#1}{\CTEX@three}%
  \or \CTEX@appendstring{#1}{\CTEX@four}%
  \or \CTEX@appendstring{#1}{\CTEX@five}%
  \or \CTEX@appendstring{#1}{\CTEX@six}%
  \or \CTEX@appendstring{#1}{\CTEX@seven}%
  \or \CTEX@appendstring{#1}{\CTEX@eight}%
  \or \CTEX@appendstring{#1}{\CTEX@nine}%
  \fi}
\def\CTEX@splitnumber#1{%
  \CTEX@q #1\relax
  \CTEX@r #1\relax
  \divide\CTEX@q \@M
  \begingroup
    \multiply\CTEX@q \@M
    \advance\CTEX@r -\CTEX@q
    \ifnum\CTEX@r = \z@
      \xdef\CTEX@low{}%
    \else
      \xdef\CTEX@low{\number\CTEX@r}%
    \fi
  \endgroup
  \ifnum\CTEX@q > \z@
    \CTEX@r \CTEX@q
    \divide\CTEX@q \@M
    \begingroup
      \multiply\CTEX@q \@M
      \advance\CTEX@r -\CTEX@q
      \ifnum\CTEX@r = \z@
        \xdef\CTEX@high{}%
      \else
        \xdef\CTEX@high{\number\CTEX@r}%
      \fi
    \endgroup
    \ifnum\CTEX@q > \z@
      \xdef\CTEX@yi{\number\CTEX@q}%
    \else
      \xdef\CTEX@yi{}%
    \fi
  \else
    \xdef\CTEX@high{}%
    \xdef\CTEX@yi{}%
  \fi
}
\def\CTEX@processnumber#1#2{%
  \CTEX@zero@false
  \CTEX@q #2\relax
  \CTEX@r #2\relax
  \divide\CTEX@q \@m
  \ifnum\CTEX@q = \z@
    \ifCTEX@previous@
      \CTEX@zero@true
    \fi
  \else
    \ifCTEX@zero@
      \CTEX@appendstring{#1}{\CTEX@zero}%
    \fi
    \CTEX@appendnumber{#1}{\CTEX@q}%
    \CTEX@appendstring{#1}{\CTEX@thousand}%
    \CTEX@previous@true
    \CTEX@zero@false
  \fi
  \multiply\CTEX@q \@m
  \advance\CTEX@r -\CTEX@q
  \CTEX@q \CTEX@r
  \divide\CTEX@q 100\relax
  \ifnum\CTEX@q = \z@
    \ifCTEX@previous@
      \CTEX@zero@true
    \fi
  \else
    \ifCTEX@zero@
      \CTEX@appendstring{#1}{\CTEX@zero}%
    \fi
    \CTEX@appendnumber{#1}{\CTEX@q}%
    \CTEX@appendstring{#1}{\CTEX@hundred}%
    \CTEX@previous@true
    \CTEX@zero@false
  \fi
  \multiply\CTEX@q 100
  \advance\CTEX@r -\CTEX@q
  \CTEX@q \CTEX@r
  \divide \CTEX@q 10\relax
  \ifnum\CTEX@q = \z@
    \ifCTEX@previous@
      \CTEX@zero@true
    \fi
  \else
    \ifCTEX@zero@
      \CTEX@appendstring{#1}{\CTEX@zero}%
    \fi
    \ifnum\CTEX@q = \@ne
      \ifCTEX@previous@
        \CTEX@appendstring{#1}{\CTEX@one}%
      \fi
    \else
      \CTEX@appendnumber{#1}{\CTEX@q}%
    \fi
    \CTEX@appendstring{#1}{\CTEX@ten}%
    \CTEX@previous@true
    \CTEX@zero@false
  \fi
  \multiply\CTEX@q 10
  \advance\CTEX@r -\CTEX@q
  \ifnum\CTEX@r = \z@
  \else
    \ifCTEX@zero@
      \CTEX@appendstring{#1}{\CTEX@zero}%
    \fi
    \CTEX@appendnumber{#1}{\CTEX@r}%
    \CTEX@previous@true
  \fi}
\DeclareRobustCommand\CTEXnumber[2]{%
  \def#1{}%
  \CTEX@null@false
  \CTEX@q #2\relax
  \ifnum\CTEX@q < \z@
    \multiply\CTEX@q \m@ne
    \CTEX@appendstring{#1}{\CTEX@minus}%
  \fi
  \CTEX@previous@false
  \CTEX@zero@false
  \ifnum\CTEX@q = \z@
    \CTEX@appendstring{#1}{\CTEX@zero}%
  \else
    \CTEX@splitnumber{\CTEX@q}%
    \ifx\CTEX@yi \@empty
    \else
      \CTEX@processnumber{#1}{\CTEX@yi}%
      \CTEX@appendstring{#1}{\CTEX@hundredmillion}%
    \fi
    \ifx\CTEX@high \@empty
    \else
      \CTEX@processnumber{#1}{\CTEX@high}%
      \CTEX@appendstring{#1}{\CTEX@tenthousand}%
    \fi
    \ifx\CTEX@low \@empty
    \else
      \ifx\CTEX@yi \@empty
      \else
        \ifx\CTEX@high \@empty
          \CTEX@appendstring{#1}{\CTEX@zero}% this catches 100002345
        \fi
      \fi
      \CTEX@processnumber{#1}{\CTEX@low}%
    \fi
  \fi}
\def\CTEX@getdigit#1#2\@nil{%
  \edef\CTEX@tempa{#1}%
  \edef\CTEX@tempb{#2}}
\DeclareRobustCommand\CTEXdigits[2]{%
  \def#1{}%
  \CTEX@null@true
  \edef\CTEX@tempa{}%
  \edef\CTEX@tempb{#2}%
  \ifx\CTEX@tempb \@empty
  \else
    \loop
      \expandafter\CTEX@getdigit\CTEX@tempb\@nil
      \CTEX@appendnumber{#1}{\CTEX@tempa}%
      \ifx\CTEX@tempb \@empty
      \else
    \repeat
  \fi}
\DeclareRobustCommand\CTEXcounter[1]{%
  \@ifundefined{c@#1}{}{%
    \CTEXnumber{\reserved@a}{\@arabic\csname c@#1\endcsname}%
    \expandafter\expandafter\expandafter\def%
    \expandafter\expandafter\csname cc@#1\endcsname%
    \expandafter{\reserved@a}}}
\AtBeginDocument{%
  \makeatletter%
  \@ifundefined{CTEX@save@setcounter}{%
    \let\CTEX@save@setcounter\setcounter%
    \def\setcounter#1#2{%
        \CTEX@save@setcounter{#1}{#2}%
        \CTEXcounter{#1}}}{}
  \@ifundefined{CTEX@save@addtocounter}{%
    \let\CTEX@save@addtocounter\addtocounter%
    \def\addtocounter#1#2{%
        \CTEX@save@addtocounter{#1}{#2}%
        \CTEXcounter{#1}}}{}
  \@ifundefined{CTEX@save@stepcounter}{%
    \let\CTEX@save@stepcounter\stepcounter%
    \def\stepcounter#1{%
        \CTEX@save@stepcounter{#1}%
        \CTEXcounter{#1}}}{}
  \makeatother}
\def\chinese#1{%
  \@ifundefined{cc@#1}{\CTEX@null}{\csname cc@#1\endcsname}}
\def\CTEX@defsecformat#1{%
  \expandafter\def\csname CTEX@pre#1\endcsname{}%
  \expandafter\def\csname CTEX@post#1\endcsname{}%
  \expandafter\def\csname CTEX@the#1\endcsname{%
    \csname the#1\endcsname}%
  \expandafter\def\csname CTEXthe#1\endcsname{%
    \csname CTEX@pre#1\endcsname%
    \csname CTEX@the#1\endcsname%
    \csname CTEX@post#1\endcsname}%
  \expandafter\def\csname CTEX@#1@format\endcsname{}%
  \expandafter\def\csname CTEX@#1@nameformat\endcsname{}%
  \expandafter\def\csname CTEX@#1@numberformat\endcsname{}%
  \expandafter\def\csname CTEX@#1@aftername\endcsname{}%
  \expandafter\def\csname CTEX@#1@titleformat\endcsname{}
  \expandafter\def\csname CTEX@#1name\endcsname{%
    \csname CTEX@#1@nameformat\endcsname%
    \csname CTEX@pre#1\endcsname%
    \begingroup%
    \csname CTEX@#1@numberformat\endcsname%
    \csname CTEX@the#1\endcsname%
    \endgroup%
    \csname CTEX@post#1\endcsname%
    \csname CTEX@#1@aftername\endcsname}%
  \expandafter\def\csname CTEX@#1@beforeskip\endcsname{}%
  \expandafter\def\csname CTEX@#1@afterskip\endcsname{}%
  \expandafter\def\csname CTEX@#1@indent\endcsname{}%
}
\CTEX@defsecformat{part}
\CTEX@defsecformat{chapter}
\CTEX@defsecformat{section}
\CTEX@defsecformat{subsection}
\CTEX@defsecformat{subsubsection}
\CTEX@defsecformat{paragraph}
\CTEX@defsecformat{subparagraph}
\def\CTEX@prepart{Part\space}
\def\CTEX@prechapter{Chapter\space}
\def\CTEX@part@format{\centering}
\def\CTEX@part@nameformat{\huge\bfseries}
\def\CTEX@part@aftername{\par\vskip 20\p@}
\def\CTEX@part@titleformat{\Huge\bfseries}
\def\CTEX@chapter@format{\raggedright}
\def\CTEX@chapter@nameformat{\huge\bfseries}
\def\CTEX@chapter@aftername{\par\nobreak\vskip 20\p@}
\def\CTEX@chapter@titleformat{\Huge\bfseries}
\def\CTEX@chapter@beforeskip{50\p@}
\def\CTEX@chapter@afterskip{40\p@}
\def\CTEX@chapter@indent{\z@}
\def\CTEX@section@format{\Large\bfseries}
\def\CTEX@section@aftername{\quad}
\def\CTEX@section@beforeskip{-3.5ex \@plus -1ex \@minus -.2ex}
\def\CTEX@section@afterskip{2.3ex \@plus .2ex}
\def\CTEX@section@indent{\z@}
\def\CTEX@subsection@format{\large\bfseries}
\def\CTEX@subsection@aftername{\quad}
\def\CTEX@subsection@beforeskip{-3.25ex \@plus -1ex \@minus -.2ex}
\def\CTEX@subsection@afterskip{1.5ex \@plus .2ex}
\def\CTEX@subsection@indent{\z@}
\def\CTEX@subsubsection@format{\normalsize\bfseries}
\def\CTEX@subsubsection@aftername{\quad}
\def\CTEX@subsubsection@beforeskip{-3.25ex \@plus -1ex \@minus -.2ex}
\def\CTEX@subsubsection@afterskip{1.5ex \@plus .2ex}
\def\CTEX@subsubsection@indent{\z@}
\def\CTEX@paragraph@format{\normalsize\bfseries}
\def\CTEX@paragraph@aftername{\quad}
\ifnum\c@CTEX@sectiondepth>2
  \def\CTEX@paragraph@beforeskip{-3.25ex \@plus -1ex \@minus -.2ex}
  \def\CTEX@paragraph@afterskip{1ex \@plus .2ex}
\else
  \def\CTEX@paragraph@beforeskip{3.25ex \@plus1ex \@minus .2ex}
  \def\CTEX@paragraph@afterskip{-1em}
\fi
\def\CTEX@paragraph@indent{\z@}
\def\CTEX@subparagraph@format{\normalsize\bfseries}
\def\CTEX@subparagraph@aftername{\quad}
\ifnum\c@CTEX@sectiondepth>3
  \def\CTEX@subparagraph@beforeskip{-3.25ex \@plus -1ex \@minus -.2ex}
  \def\CTEX@subparagraph@afterskip{1ex \@plus .2ex}
\else
  \def\CTEX@subparagraph@beforeskip{3.25ex \@plus1ex \@minus .2ex}
  \def\CTEX@subparagraph@afterskip{-1em}
\fi
\ifnum\c@CTEX@sectiondepth>2
  \def\CTEX@subparagraph@indent{\z@}
\else
  \def\CTEX@subparagraph@indent{\parindent}
\fi
\def\CTEX@appendixname{Appendix\space}
\def\CTEX@appendixnumber{\@Alph\c@chapter}
\let\CTEX@save@appendix\appendix
\renewcommand*\appendix{\CTEX@save@appendix%
  \gdef\CTEX@prechapter{\CTEX@appendixname}%
  \gdef\CTEX@thechapter{\CTEX@appendixnumber}%
  \gdef\CTEX@postchapter{}}%
\def\@part[#1]#2{%
  \ifnum \c@secnumdepth >-2\relax
    \refstepcounter{part}%
    \addcontentsline{toc}{part}{\CTEXthepart\hspace{1em}#1}%
  \else
    \addcontentsline{toc}{part}{#1}%
  \fi
  \markboth{}{}%
  {\interlinepenalty \@M
   \normalfont \CTEX@part@format
   \ifnum \c@secnumdepth >-2\relax
     \CTEX@partname
   \fi
   \CTEX@part@titleformat #2\par}%
  \@endpart}
\def\@spart#1{%
    {\interlinepenalty \@M
     \normalfont \CTEX@part@format
     \CTEX@part@titleformat #1\par}%
    \@endpart}
\def\@chapter[#1]#2{%
  \ifnum \c@secnumdepth >\m@ne
    \if@mainmatter
      \refstepcounter{chapter}%
      \typeout{\CTEXthechapter}%
      \addcontentsline{toc}{chapter}
        {\protect\numberline{\CTEXthechapter\hspace{0.3em}}#1}%
    \else
      \addcontentsline{toc}{chapter}{#1}%
    \fi
  \else
    \addcontentsline{toc}{chapter}{#1}%
  \fi
  \chaptermark{#1}%
  \addtocontents{lof}{\protect\addvspace{10\p@}}%
  \addtocontents{lot}{\protect\addvspace{10\p@}}%
  \if@twocolumn
    \@topnewpage[\@makechapterhead{#2}]%
  \else
    \@makechapterhead{#2}%
  \@afterheading
  \fi}
\def\@makechapterhead#1{%
  \vspace*{\CTEX@chapter@beforeskip}%
  {\normalfont \parindent \CTEX@chapter@indent \CTEX@chapter@format
   \ifnum \c@secnumdepth >\m@ne
     \if@mainmatter
       \CTEX@chaptername
     \fi
   \fi
   \interlinepenalty\@M
   \CTEX@chapter@titleformat #1\par\nobreak
   \vskip \CTEX@chapter@afterskip
  }}
\def\@makeschapterhead#1{%
  \vspace*{\CTEX@chapter@beforeskip}%
  {\normalfont \parindent \CTEX@chapter@indent \CTEX@chapter@format
   \interlinepenalty\@M
   \CTEX@chapter@titleformat #1\par\nobreak
   \vskip \CTEX@chapter@afterskip
  }}
\def\@seccntformat#1{%
  \@ifundefined{CTEX@#1name}%
    {\csname the#1\endcsname\quad}%
    {\csname CTEX@#1name\endcsname}}
\def\@sect#1#2#3#4#5#6[#7]#8{%
  \ifnum #2>\c@secnumdepth
    \let\@svsec\@empty
  \else
    \refstepcounter{#1}%
    \protected@edef\@svsec{\@seccntformat{#1}\relax}%
  \fi
  \@tempskipa #5\relax
  \ifdim \@tempskipa>\z@
    \begingroup
      #6{%
        \@hangfrom{\hskip #3\relax\@svsec}%
        \interlinepenalty \@M
        \csname CTEX@#1@titleformat\endcsname #8\@@par}%
    \endgroup
    \csname #1mark\endcsname{#7}%
    \addcontentsline{toc}{#1}{%
      \ifnum #2>\c@secnumdepth \else
        \protect\numberline{\@ifundefined{CTEXthe#1}%
                              {\csname the#1\endcsname}%
                              {\csname CTEXthe#1\endcsname}}%
      \fi
      #7}%
  \else
    \def\@svsechd{%
    #6{\hskip #3\relax
      \@svsec \csname CTEX@#1@titleformat\endcsname #8}%
    \csname #1mark\endcsname{#7}%
    \addcontentsline{toc}{#1}{%
      \ifnum #2>\c@secnumdepth \else
        \protect\numberline{\@ifundefined{CTEXthe#1}%
                              {\csname the#1\endcsname}%
                              {\csname CTEXthe#1\endcsname}}%
      \fi
      #7}}%
  \fi
  \@xsect{#5}}
\def\numberline#1{%
  \settowidth\@tempdimb{#1\hspace{0.5em}}%
  \ifdim\@tempdima<\@tempdimb%
    \@tempdima=\@tempdimb%
  \fi%
  \hb@xt@\@tempdima{#1\hfil}}
\renewcommand\section{\@startsection{section}{1}%
                                   {\CTEX@section@indent}%
                                   {\CTEX@section@beforeskip}%
                                   {\CTEX@section@afterskip}%
                                   {\normalfont\CTEX@section@format}}
\renewcommand\subsection{\@startsection{subsection}{2}%
                                   {\CTEX@subsection@indent}%
                                   {\CTEX@subsection@beforeskip}%
                                   {\CTEX@subsection@afterskip}%
                                   {\normalfont\CTEX@subsection@format}}
\renewcommand\subsubsection{\@startsection{subsubsection}{3}%
                                   {\CTEX@subsubsection@indent}%
                                   {\CTEX@subsubsection@beforeskip}%
                                   {\CTEX@subsubsection@afterskip}%
                                   {\normalfont\CTEX@subsubsection@format}}
\renewcommand\paragraph{\@startsection{paragraph}{4}%
                                   {\CTEX@paragraph@indent}%
                                   {\CTEX@paragraph@beforeskip}%
                                   {\CTEX@paragraph@afterskip}%
                                   {\normalfont\CTEX@paragraph@format}}
\renewcommand\subparagraph{\@startsection{subparagraph}{5}%
                                   {\CTEX@subparagraph@indent}%
                                   {\CTEX@subparagraph@beforeskip}%
                                   {\CTEX@subparagraph@afterskip}%
                                   {\normalfont\CTEX@subparagraph@format}}
\if@twoside
  \def\ps@headings{%
      \let\@oddfoot\@empty\let\@evenfoot\@empty
      \def\@evenhead{\thepage\hfil\slshape\leftmark}%
      \def\@oddhead{{\slshape\rightmark}\hfil\thepage}%
      \let\@mkboth\markboth
    \def\chaptermark##1{%
      \markboth {\MakeUppercase{%
        \ifnum \c@secnumdepth >\m@ne
          \if@mainmatter
            \CTEXthechapter \quad %
          \fi
        \fi
        ##1}}{}}%
    \def\sectionmark##1{%
      \markright {\MakeUppercase{%
        \ifnum \c@secnumdepth >\z@
          \CTEXthesection \quad %
        \fi
        ##1}}}}
\else
  \def\ps@headings{%
    \let\@oddfoot\@empty
    \def\@oddhead{{\slshape\rightmark}\hfil\thepage}%
    \let\@mkboth\markboth
    \def\chaptermark##1{%
      \markright {\MakeUppercase{%
        \ifnum \c@secnumdepth >\m@ne
          \if@mainmatter
            \CTEXthechapter \quad %
          \fi
        \fi
        ##1}}}}
\fi
\pagestyle{headings}
\@ifundefined{ps@fancy}{}{%
  \def\ps@fancy{%
  \@ifundefined{@chapapp}{\let\@chapapp\chaptername}{}%for amsbook
  \@ifundefined{MakeUppercase}{\def\MakeUppercase{\uppercase}}{}%
  \@ifundefined{chapter}{\def\sectionmark##1{\markboth
  {\MakeUppercase{\ifnum \c@secnumdepth>\z@
   \CTEXthesection\quad \fi ##1}}{}}%
  \def\subsectionmark##1{\markright {\ifnum \c@secnumdepth >\@ne
   \CTEXthesubsection\quad \fi ##1}}}%
  {\def\chaptermark##1{\markboth {\MakeUppercase{\ifnum \c@secnumdepth>\m@ne
   \ifCTEX@cls{book}{\if@mainmatter\CTEXthechapter \quad\fi}{\CTEXthechapter \quad}
   \fi ##1}}{}}%
  \def\sectionmark##1{\markright{\MakeUppercase{\ifnum \c@secnumdepth >\z@
   \CTEXthesection \quad \fi ##1}}}}%
  \ps@@fancy
  \gdef\ps@fancy{\@fancyplainfalse\ps@@fancy}%
  \ifdim\headwidth<0sp
      \global\advance\headwidth123456789sp\global\advance\headwidth\textwidth
  \fi}
}
\ifCTEX@caption
  \let\CTEX@save@refstepcounter\refstepcounter
  \def\refstepcounter#1{\stepcounter{#1}%
    \protected@edef\@currentlabel
      {\csname p@#1\endcsname%
       \@ifundefined{CTEX@the#1}%
         {\csname the#1\endcsname}%
         {\csname CTEX@the#1\endcsname}%
       }}%
\fi
\def\CTEX@contentsname{Contents}
\def\CTEX@listfigurename{List of Figures}
\def\CTEX@listtablename{List of Tables}
\def\CTEX@figurename{Figure}
\def\CTEX@tablename{Table}
\def\CTEX@abstractname{Abstract}
\def\CTEX@indexname{Index}
\def\CTEX@bibname{Bibliography}
\renewcommand*\contentsname{\CTEX@contentsname}
\renewcommand*\listfigurename{\CTEX@listfigurename}
\renewcommand*\listtablename{\CTEX@listtablename}
\renewcommand*\figurename{\CTEX@figurename}
\renewcommand*\tablename{\CTEX@tablename}
\@ifundefined{abstractname}{}{
  \renewcommand*\abstractname{\CTEX@abstractname}}
\renewcommand*\partname{\CTEX@thepart}
\@ifundefined{chaptername}{}{
  \renewcommand*\chaptername{\CTEX@thechapter}}
\renewcommand*\appendixname{\CTEX@appendixname}
\renewcommand*\indexname{\CTEX@indexname}
  \renewcommand*\bibname{\CTEX@bibname}
\def\CTEX@setsecname#1[#2,#3]{%
  \expandafter\def\csname CTEX@pre#1\endcsname{#2}%
  \expandafter\def\csname CTEX@post#1\endcsname{\ignorespaces#3}}
\def\CTEX@setsecnumber#1[#2]{%
  \expandafter\def\csname CTEX@the#1\endcsname{#2}}
\def\CTEX@setsecformat#1#2[#3]{%
  \expandafter\def\csname CTEX@#1@#2\endcsname{#3}}
\def\CTEX@addsecformat#1#2[#3]{%
  \expandafter\let\expandafter\reserved@a\csname CTEX@#1@#2\endcsname%
  \expandafter\expandafter\expandafter\def\expandafter\expandafter%
    \csname CTEX@#1@#2\endcsname\expandafter{\reserved@a#3}}
\def\CTEX@defseckey#1{%
  \CTEX@subkey{#1}{name}{\CTEX@setsecname{#1}[##1]}%
  \CTEX@subkey{#1}{number}{\CTEX@setsecnumber{#1}[##1]}%
  \CTEX@subkey{#1}{format}{\CTEX@setsecformat{#1}{format}[##1]}%
  \CTEX@subkey{#1}{format+}{\CTEX@addsecformat{#1}{format}[##1]}%
  \CTEX@subkey{#1}{nameformat}{\CTEX@setsecformat{#1}{nameformat}[##1]}%
  \CTEX@subkey{#1}{nameformat+}{\CTEX@addsecformat{#1}{nameformat}[##1]}%
  \CTEX@subkey{#1}{numberformat}{\CTEX@setsecformat{#1}{numberformat}[##1]}%
  \CTEX@subkey{#1}{numberformat+}{\CTEX@addsecformat{#1}{numberformat}[##1]}%
  \CTEX@subkey{#1}{aftername}{\CTEX@setsecformat{#1}{aftername}[##1]}%
  \CTEX@subkey{#1}{aftername+}{\CTEX@addsecformat{#1}{aftername}[##1]}%
  \CTEX@subkey{#1}{titleformat}{\CTEX@setsecformat{#1}{titleformat}[##1]}%
  \CTEX@subkey{#1}{titleformat+}{\CTEX@addsecformat{#1}{titleformat}[##1]}%
  \CTEX@subkey{#1}{beforeskip}{\CTEX@setsecformat{#1}{beforeskip}[##1]}%
  \CTEX@subkey{#1}{afterskip}{\CTEX@setsecformat{#1}{afterskip}[##1]}%
  \CTEX@subkey{#1}{indent}{\CTEX@setsecformat{#1}{indent}[##1]}%
}
\CTEX@defseckey{part}
\CTEX@defseckey{chapter}
\CTEX@defseckey{section}
\CTEX@defseckey{subsection}
\CTEX@defseckey{subsubsection}
\CTEX@defseckey{paragraph}
\CTEX@defseckey{subparagraph}
\CTEX@subkey{appendix}{name}{\def\CTEX@appendixname{#1}}
\CTEX@subkey{appendix}{number}{\def\CTEX@appendixnumber{#1}}
\CTEX@key{contentsname}{\def\CTEX@contentsname{#1}}
\CTEX@key{listfigurename}{\def\CTEX@listfigurename{#1}}
\CTEX@key{listtablename}{\def\CTEX@listtablename{#1}}
\CTEX@key{figurename}{\def\CTEX@figurename{#1}}
\CTEX@key{tablename}{\def\CTEX@tablename{#1}}
\CTEX@key{abstractname}{\def\CTEX@abstractname{#1}}
\CTEX@key{indexname}{\def\CTEX@indexname{#1}}
\CTEX@key{bibname}{\def\CTEX@bibname{#1}}
\let\CTEX@todayold\today
\let\CTEX@todaysmall\today
\let\CTEX@todaybig\today
\ifCTEX@caption
  \renewcommand*\today{\CTEX@todaysmall}
\fi
\CTEX@key{today}{\CTEX@settoday{#1}}
\newcommand*\CTEX@settoday[1]{%
  \@ifundefined{CTEX@today#1}
    {\PackageError{ctex}{%
       unknown today format}{%
       Available today format are "old", "small", and "big".}}
    {\renewcommand*\today{\csname CTEX@today#1\endcsname}}}
\def\CTEX@caption@delimiter{: }
\long\def\@makecaption#1#2{%
  \vskip\abovecaptionskip
  \sbox\@tempboxa{#1\CTEX@caption@delimiter #2}%
  \ifdim \wd\@tempboxa >\hsize
    #1\CTEX@caption@delimiter #2\par
  \else
    \global \@minipagefalse
    \hb@xt@\hsize{\hfil\box\@tempboxa\hfil}%
  \fi
  \vskip\belowcaptionskip}
\CTEX@key{captiondelimiter}{\CTEX@setcaptiondelimiter{#1}}
\newcommand*\CTEX@setcaptiondelimiter[1]{%
  \def\CTEX@caption@delimiter{#1}}
\endinput
%%
%% End of file `ctexbook.cls'.
