TEXOPT = --purgeall --xtx
NONSRC = cmds.pdf ../cmds.pdf
TEMP =  cmds.tui cmds.log cmds.tmp cmds.tuo *.mp

cmds.pdf: cmds.tex
	@echo "ConTeXting..."
	@texexec $(TEXOPT) cmds.tex
	@mv cmds.pdf ../
	@echo "Done."

all: cmds.pdf
	@echo "All done."

clean: cleantemp
	@echo "Cleaning pdf..."
	@rm -fv $(NONSRC)
	@echo "Done."

cleantemp:
	@echo "Cleaning..."
	@rm -fv $(TEMP)
	@echo "Done."
