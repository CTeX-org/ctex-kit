#!/bin/sh

mkdir t && cd t || exit 1

cp ../utf8.tex utf8-cjkfonts.tex
cp ../utf8.tex utf8-winfonts.tex
cp ../utf8.tex utf8-adobefonts.tex

sed -i -e 's/\<winfonts\>/cjkfonts/' utf8-cjkfonts.tex
sed -i -e 's/\<winfonts\>/adobefonts/' utf8-adobefonts.tex

for f in *.tex; do
    for t in xelatex pdflatex dvipdfmx; do
        make -f ../Makefile TOOLCHAINS="$t,$t" "${f%.tex}"
    done

    sed -i -e 's/\<dvipdfmx\>/ps2pdf/' "$f"
    make -f ../Makefile TOOLCHAINS=dvips,dvips "${f%.tex}"
done

