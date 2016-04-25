zhmetrics-uptex
===============================================

**2016/04/23 Ver 1.0**

The `zhmetrics-uptex` package contains some Chinese font metrics (JFM, VF, etc) for upTeX engine, together with a simple DVIPDFMx font mapping of Fandol fonts for DVIPDFMx.

The font mapping can be loaded in the TeX source file, or changed in the document to use other fonts.

Files
-----

* `upzh*-{h,v}.tfm` are the JFM files used by upTeX.
* `upzh*-{h,v}.vf` are the virtual fonts used by the output driver (dvipdfmx).
* `up*-{h,v}.tfm` are the PS TFM files used by the output driver.
* `upzhfandolfonts.tex` contains the font mappings of Fandol fonts for DVIPDFMx.
* `upzhfandolfonts-test.tex` is a small LaTeX test file.
* `upzhm-{h,v}.pl` are the JPL source files used to produce JFM files.
* `makemetrics.lua` is the build script.

Build
-----

To create the metric files, just run:
```shell
texlua makemetrics.lua
```
in the source directory.

Contributing
------------

This font package is a part of the [ctex-kit](https://github.com/CTeX-org/ctex-kit) project.

Issues and pull requests are welcome.

Copyright and Licence
---------------------

Copyright (C) 2016 by Leo Liu <leoliu.pku@gmail.com>

This work may be distributed and/or modified under the conditions of the LaTeX Project Public License, either version 1.3 of this license or (at your option) any later version. The latest version of this license is in
  http://www.latex-project.org/lppl.txt
and version 1.3 or later is part of all distributions of LaTeX version 2005/12/01 or later.

This work has the LPPL maintenance status `maintained'.

The Current Maintainer of this work is Leo Liu.

This work consists of the files
        makemetrics.lua
        upzhm-{h,v}.pl
        upzhfandolfonts.tex
        upzhfandolfongs-test.tex
        README.md
and the derived files
        upzhserif-{h,v}.tfm
        upzhserifit-{h,v}.tfm
        upzhserifb-{h,v}.tfm
        upzhsans-{h,v}.tfm
        upzhsnasb-{h,v}.tfm
        upzhmono-{h,v}.tfm
        upzhserif-{h,v}.vf
        upzhserifit-{h,v}.vf
        upzhserifb-{h,v}.vf
        upzhsans-{h,v}.vf
        upzhsnasb-{h,v}.vf
        upzhmono-{h,v}.vf
        upserif-{h,v}.tfm
        upserifit-{h,v}.tfm
        upserifb-{h,v}.tfm
        upsans-{h,v}.tfm
        upsnasb-{h,v}.tfm
        upmono-{h,v}.tfm
