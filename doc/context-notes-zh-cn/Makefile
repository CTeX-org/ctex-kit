PRODUCT=ctxnotes
READER=evince

all:
	context --mode=screen $(PRODUCT)

print:
	context --mode=print $(PRODUCT)
	context --purge

bib:
	context --mode=screen --once $(PRODUCT) \
        && bibtex $(PRODUCT) \
        && context --mode=screen $(PRODUCT)

pdf:
	$(READER) $(PRODUCT).pdf &

clean:
	context --purge
	rm -f *.aux *.bbl *.blg
	rm -f *.pdf
