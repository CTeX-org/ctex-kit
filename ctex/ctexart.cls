% ctexart.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexart}
  [2012/04/09 v1.04 ctexart
   document class]

\def\CTEX@classtoload{article}

\input{ctex-options.def}

\input{ctex-common.def}

\input{ctex-caption.def}

\input{ctex-fontsize.def}

\input{ctex-article.def}

% ctex.cfg should be loaded very last
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.cfg}{}{}
  \makeatother}

\endinput
