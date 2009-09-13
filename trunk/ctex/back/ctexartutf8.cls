% ctexartutf8.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexartutf8}
  [2009/09/13 v0.94 ctexartutf8
   document class]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ctexart}}
\PassOptionsToClass{UTF8}{ctexart}
\ProcessOptions
\LoadClass{ctexart}

\endinput
