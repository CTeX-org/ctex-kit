% ctexbookutf8.cls

\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{ctexbookutf8}
  [2012/04/09 v1.04  ctexbookutf8
   document class]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ctexbook}}
\PassOptionsToClass{UTF8}{ctexbook}
\ProcessOptions
\LoadClass{ctexbook}

\endinput
