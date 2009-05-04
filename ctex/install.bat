@echo off
if (%1)==(doc) goto document
if (%1)==(doC) goto document
if (%1)==(dOc) goto document
if (%1)==(dOC) goto document
if (%1)==(Doc) goto document
if (%1)==(DoC) goto document
if (%1)==(DOc) goto document
if (%1)==(DOC) goto document



:install

latex ctex.ins

echo "Please refresh the filename database"

if (%1)==(all) goto document
if (%1)==(alL) goto document
if (%1)==(aLl) goto document
if (%1)==(aLL) goto document
if (%1)==(All) goto document
if (%1)==(AlL) goto document
if (%1)==(ALl) goto document
if (%1)==(ALL) goto document
goto end



:document

latex ctex.dtx
latex ctex.dtx
makeindex -s gind.ist -o ctex.ind ctex.idx
makeindex -s gglo.ist -o ctex.gls ctex.glo
latex ctex.dtx
dvips ctex.dvi

echo "Now you can read the document (ctex.dvi or ctex.ps)"



:end
