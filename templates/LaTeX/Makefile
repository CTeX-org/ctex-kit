.PHONY: $(MAKECMDGOALS) makefile-help

makefile-help:
	@echo Usage:
	@echo '  make [TOOLCHAINS=xelatx,pdflatex,dvipdfmx,dvips] [SYNCTEX=0] doc-without-suffix...'
	@echo
	@echo xelatex is the default toolchain.


AVAILABLE_TOOLCHAINS := xelatex pdflatex dvipdfmx dvips
SYNCTEX := 1

define xelatex
%$1.pdf : %.tex
	xelatex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	xelatex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
endef

define pdflatex
%$1.pdf : %.tex
	pdflatex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	pdflatex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	if grep -q "^[^%].*\\documentclass\s*\[.*GBK" $$< ; then \
		gbk2uni $$(@:.pdf=.out) ; \
		pdflatex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$< ; \
	fi
endef

define dvipdfmx
%$1.pdf : %.tex
	latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	if grep -q "^[^%].*\\documentclass\s*\[.*GBK" $$< ; then \
		if ! kpsewhich -format="cmap files" GBK-EUC-UCS2 ; then \
			gbk2uni $$(@:.pdf=.out) ; \
			latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$< ; \
		fi ; \
	fi
	dvipdfmx $$(@:.pdf=.dvi)
endef

define dvips
%$1.pdf : %.tex
	latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$<
	if grep -q "^[^%].*\\documentclass\s*\[.*GBK" $$< ; then \
		gbk2uni $$(@:.pdf=.out) ; \
		latex -jobname="$$(@:.pdf=)" -synctex=$(SYNCTEX) $$< ; \
	fi
	dvips $$(@:.pdf=.dvi)
	ps2pdf $$(@:.pdf=.ps)
endef


override TOOLCHAINS := $(strip $(TOOLCHAINS))
ifeq ($(TOOLCHAINS),)
	override TOOLCHAINS := xelatex
endif

comma := ,
empty :=
space := $(empty) $(empty)
override TOOLCHAINS := $(subst $(comma),$(space),$(TOOLCHAINS))

ifneq ($(filter-out $(AVAILABLE_TOOLCHAINS),$(TOOLCHAINS)),)
$(error Unrecognized toolchains: $(TOOLCHAINS) (available: $(AVAILABLE_TOOLCHAINS)))
endif

SOURCES := $(filter-out clean distclean,$(MAKECMDGOALS))

ifneq ($(SOURCES),)
ifeq ($(words $(TOOLCHAINS)),1)
$(SOURCES): % : %.pdf
$(eval $(call $(TOOLCHAINS)))
else
$(SOURCES): % : $(addprefix %-,$(addsuffix .pdf,$(TOOLCHAINS)))
$(foreach toolchain,$(TOOLCHAINS),$(eval $(call $(toolchain),-$(toolchain))))
endif
endif

clean:
	rm -f *.log *.aux *.toc *.out *.dvi *.xdv *.synctex.gz *.out.bak

distclean: clean
	rm -f *.pdf *.ps

