# public domain
all: book.dvi book.pdf #book.html

book.dvi: fdl.tex preface.tex
	tex '\nonstopmode\input book'
book.pdf: fdl.tex preface.tex
	pdftex '\nonstopmode\input book'
book.html:
	httex book.tex

dist: all
	rm -f x.tex
	tar czf impatient.tgz Makefile README *.icn \
	        *.tex book.aux book.idx book.toc book.ccs book.sdx \
		book.dvi book.pdf
