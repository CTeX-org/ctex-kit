% ctexreputf8.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexreputf8}
  [2010/01/22 v0.97 ctexreputf8
   document class]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ctexrep}}
\PassOptionsToClass{UTF8}{ctexrep}
\ProcessOptions
\LoadClass{ctexrep}

\endinput
