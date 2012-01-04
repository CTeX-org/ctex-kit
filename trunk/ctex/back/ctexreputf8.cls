% ctexreputf8.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexreputf8}
  [2011/09/23 v1.03 ctexreputf8
   document class]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ctexrep}}
\PassOptionsToClass{UTF8}{ctexrep}
\ProcessOptions
\LoadClass{ctexrep}

\endinput
