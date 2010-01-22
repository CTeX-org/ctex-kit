% ctexart.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexart}
  [2010/01/22 v0.97 ctexart
   document class]

\def\CTEX@classtoload{article}

\input{ctex-common-opts.def}
\input{ctex-caption-opts.def}
\input{ctex-class-opts.def}

\InputIfFileExists{ctexopts.cfg}{}{}

\input{ctex-loadclass.def}

\input{ctex-common.def}
\input{ctex-caption.def}
\input{ctex-class.def}
\input{ctex-article.def}

% ctex.cfg should be loaded very last
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.cfg}{}{}
  \makeatother}

\endinput
