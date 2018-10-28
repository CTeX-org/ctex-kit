zhlineskip
==========

`zhlineskip` is a package for typesetting CJK documents. This package allows users
to specify the two ratios between the leading and the font size of the body text
and the footnote text. For Latin typesetting, these ratios usually range
[from&nbsp;1.2 to&nbsp;1.45](https://practicaltypography.com/line-spacing.html),
but they should be larger for CJK typesetting (usually from&nbsp;1.5 to&nbsp;1.67).

On the one hand, CJK text requires larger line spacing. On the other hand, math
line spacing should follow Latin typesetting, since math often consists of only
Latin letters and symbols. The `zhlineskip` package is capable of restoring the
math leading to that of the Latin text.

Finally, it is possible to achieve the “Microsoft Word multiple line spacing”
style using `zhlineskip`.

Contributing
------------

This package is a part of the [CTeX-kit](https://github.com/CTeX-org/ctex-kit) project.

Issues and pull requests are welcome.

Copyright and Licence
---------------------

    Copyright (C) 2018 by Ruixi Zhang <ruixizhang42@gmail.com>
    
    This work may be distributed and/or modified under the
    conditions of the LaTeX Project Public License, either version 1.3
    of this license or (at your option) any later version.
    The latest version of this license is in
      http://www.latex-project.org/lppl.txt
    and version 1.3 or later is part of all distributions of LaTeX
    version 2005/12/01 or later.
    
    This work has the LPPL maintenance status `maintained'.
    
    The Current Maintainer of this work is Ruixi Zhang.
    
    This work consists of the files zhlineskip.sty,
                                    zhlineskip-man.tex,
                                    zhlineskip-test.tex,
                                    Latinmetrics.pdf,
                                    CJKmetrics.pdf,
                                    README.md (this file)
              and the derived file  zhlineskip-man.pdf.