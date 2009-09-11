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
	xelatex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
	xelatex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
endef

define pdflatex
%$1.pdf : %.tex
	pdflatex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
	pdflatex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
endef

define dvipdfmx
%$1.pdf : %.tex
	latex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
	latex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
	dvipdfmx $$(@:.pdf=.dvi)
endef

define dvips
%$1.pdf : %.tex
	latex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
	latex -jobname=$$(basename $$@) -synctex=$(SYNCTEX) $$<
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
	rm -f *.log *.aux *.toc *.out *.dvi *.xdv *.synctex.gz

distclean: clean
	rm -f *.pdf *.ps

