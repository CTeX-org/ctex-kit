#!/bin/sh

mkdir t || exit 1
cd t || exit 1

cp ../gbk.tex gbk-cjkfonts.tex
cp ../gbk.tex gbk-winfonts.tex
cp ../gbk.tex gbk-adobefonts.tex

cp ../utf8.tex utf8-cjkfonts.tex
cp ../utf8.tex utf8-winfonts.tex
cp ../utf8.tex utf8-adobefonts.tex

sed -i -e 's/\<winfonts\>/cjkfonts/' gbk-cjkfonts.tex utf8-cjkfonts.tex

sed -i -e 's/\<winfonts\>/adobefonts/' gbk-adobefonts.tex utf8-adobefonts.tex

for f in *.tex; do
    for t in xelatex pdflatex dvipdfmx; do
        make -f ../Makefile TOOLCHAINS=$t,$t `basename $f .tex`
    done

    sed -i -e 's/\<dvipdfmx\>/ps2pdf/' $f
    make -f ../Makefile TOOLCHAINS=dvips,dvips `basename $f .tex`
done

