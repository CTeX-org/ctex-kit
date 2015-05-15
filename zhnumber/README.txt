Introduction
------------
The zhnumber package provides commands to typeset Chinese representations of
numbers. The main difference between this package and 'CJKnumb' is that commands
provided by this package is expandable in the proper way. So, it seems that
zhnumber is a good alternative to CJKnumb package.

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this license or
(at your option) any later version. The latest version of this license is in

   http://www.latex-project.org/lppl.txt

and version 1.3 or later is part of all distributions of LaTeX version
2005/12/01 or later.

This work has the LPPL maintenance status "maintained".
The Current Maintainer of this work is Qing Lee.

This work consists of the file  zhnumber.dtx,
          and the derived files zhnumber.pdf,
                                zhnumber.sty,
                                zhnumber-utf8.cfg,
                                zhnumber-gbk.cfg,
                                zhnumber-big5.cfg,
                                zhnumber.ins and
                                README (this file).

Basic Usage
-----------
The package provides the following macros:

  \zhnumber{number}
    Convert `number' to a full Chinese representation.

  \zhnum{counter}
    Similar to \arabic{counter}, but representation of 'counter' as Chinese numerals.

  \zhdigits{number}
  \zhdigits*{number}
    Handle `number' as a string of digits and convert each of them into the
    corresponding Chinese digit. The starred version uses the Chinese circle glyph
    for digit zero; the unstarred version uses the traditional glyph.

You can read the package manual (in Chinese) for more detailed explanations.

Author
------
Qing Lee
Email: sobenlee@gmail.com

If you are interested in the process of development you may observe

    http://code.google.com/p/ctex-kit/

Installation
------------
The package is supplied in dtx format and as a pre-extracted zip file,
zhnumber.tds.zip. The later is most convenient for most users: simply
unzip this in your local texmf directory and run texhash to update the
database of file locations. If you want to unpack the dtx yourself, please
ensure that the "iconv" program is installed and working properly, then
running "xetex -shell-escape zhnumber.dtx" will extract the package whereas
"xelatex zhnumber.dtx" will typeset the documentation.

The package requires LaTeX3 support as provided in the l3kernel and l3packages
bundles. Both of these are available on CTAN as ready-to-install zip files.
Suitable versions are available in the latest version of MiKTeX and TeX Live
(updating the relevant packages online may be necessary).

To compile the documentation without error, you will need the xeCJK package
and some specific Chinese Simplified fonts (TrueType or OpenType).
