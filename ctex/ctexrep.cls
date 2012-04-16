% ctexrep.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexrep}
  [2012/04/16 v1.10 ctexrep
   document class]

\def\CTEX@classtoload{report}

\input{ctex-options.def}

\input{ctex-common.def}

\input{ctex-caption.def}

\input{ctex-fontsize.def}

\input{ctex-report.def}

% ctex.cfg should be loaded very last
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.cfg}{}{}
  \makeatother}

\endinput
