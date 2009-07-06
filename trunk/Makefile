ZIPFLAGS = -r
BUILD_DIR = build
CJKPUNCT_DIR = $(BUILD_DIR)/CJKpunct
CTEX_DIR = $(BUILD_DIR)/ctex
XECJK_DIR = $(BUILD_DIR)/xecjk
ZHS_DIR = $(BUILD_DIR)/zhspacing
ZIPS = $(BUILD_DIR)/CJKpunct.zip $(BUILD_DIR)/xecjk.zip $(BUILD_DIR)/zhspacing.zip $(BUILD_DIR)/ctex.zip

all: $(ZIPS)

$(BUILD_DIR)/CJKpunct.zip: CJKpunct/README
	rm -rf $(CJKPUNCT_DIR)
	mkdir -p $(CJKPUNCT_DIR)
	cp CJKpunct/README $(CJKPUNCT_DIR)
	cp -r CJKpunct/doc/latex/cjk/cjkpunct/* $(CJKPUNCT_DIR)
	cp -r CJKpunct/source/latex/cjk/cjkpunct/CJKpunct.dtx CJKpunct/source/latex/cjk/cjkpunct/setpunct $(CJKPUNCT_DIR)
	cp -r CJKpunct/source/latex/cjk/cjkpunct/README.txt $(CJKPUNCT_DIR)/README.zh-cn.txt
	cp CJKpunct/tex/latex/CJK/CJKpunct/* $(CJKPUNCT_DIR)
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) CJKpunct.zip CJKpunct

$(BUILD_DIR)/xecjk.zip: xecjk/README
	rm -rf $(XECJK_DIR)
	mkdir -p $(XECJK_DIR)
	cp xecjk/README $(XECJK_DIR)
	cp -r xecjk/doc/xelatex/xecjk/* $(XECJK_DIR)
	cp xecjk/source/xelatex/xecjk/*.dtx $(XECJK_DIR)
	cp xecjk/tex/xelatex/xecjk/xeCJK.sty $(XECJK_DIR)
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) xecjk.zip xecjk

$(BUILD_DIR)/zhspacing.zip: zhspacing/README
	rm -rf $(ZHS_DIR)
	mkdir -p $(ZHS_DIR)/doc
	cp zhspacing/README $(ZHS_DIR)
	cp zhspacing/doc/zhs-man.tex zhspacing/doc/zhs-man.pdf zhspacing/test/* $(ZHS_DIR)/doc
	cp -r zhspacing/tex/* $(ZHS_DIR)
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) zhspacing.zip zhspacing

$(BUILD_DIR)/ctex.zip: ctex/README
	rm -rf $(CTEX_DIR)
	mkdir -p $(CTEX_DIR)/doc
	mkdir -p $(CTEX_DIR)/test
	cp ctex/README $(CTEX_DIR)
	cp ctex/*.sty ctex/*.cls $(CTEX_DIR)
	cp -r ctex/back ctex/cfg ctex/def ctex/engine ctex/fontset ctex/fd ctex/opt $(CTEX_DIR)
	cp ctex/test/*.tex $(CTEX_DIR)/test
	cp ctex/doc/ctex.pdf ctex/doc/ctex.tex $(CTEX_DIR)/doc
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) ctex.zip ctex

clean:
	rm -rf $(BUILD_DIR)/*

