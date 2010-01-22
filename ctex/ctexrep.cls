% ctexrep.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexrep}
  [2010/01/22 v0.97 ctexrep
   document class]

\def\CTEX@classtoload{report}

\input{ctex-common-opts.def}
\input{ctex-caption-opts.def}
\input{ctex-class-opts.def}

\InputIfFileExists{ctexopts.cfg}{}{}

\input{ctex-loadclass.def}

\input{ctex-common.def}
\input{ctex-caption.def}
\input{ctex-class.def}
\input{ctex-report.def}

% ctex.cfg should be loaded very last
\AtEndOfPackage{%
  \makeatletter
  \InputIfFileExists{ctex.cfg}{}{}
  \makeatother}

\endinput
