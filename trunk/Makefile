ZIPFLAGS = -r
BUILD_DIR = build
CTEX_DIR = $(BUILD_DIR)/ctex
XECJK_DIR = $(BUILD_DIR)/xecjk
ZHS_DIR = $(BUILD_DIR)/ZHSPACING
ZIPS = $(BUILD_DIR)/CJKpunct.zip $(BUILD_DIR)/xecjk.zip $(BUILD_DIR)/zhspacing.zip $(BUILD_DIR)/ctex.zip

all: $(ZIPS)

$(BUILD_DIR)/CJKpunct.zip: CJKpunct/README
	mkdir -p $(BUILD_DIR)
	zip $(ZIPFLAGS) $@ CJKpunct

$(BUILD_DIR)/xecjk.zip: xecjk/README
	mkdir -p $(BUILD_DIR)
	zip $(ZIPFLAGS) $@ xecjk

$(BUILD_DIR)/zhspacing.zip: zhspacing/README
	rm -rf $(ZHS_DIR)
	mkdir -p $(ZHS_DIR)/doc/xetex/zhspacing
	cp zhspacing/README $(ZHS_DIR)
	cp zhspacing/doc/zhs-man.tex zhspacing/doc/zhs-man.pdf zhspacing/test/* $(ZHS_DIR)/doc/xetex/zhspacing
	cp -r zhspacing/tex $(ZHS_DIR)/tex
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) zhspacing.zip zhspacing

$(BUILD_DIR)/ctex.zip: ctex/README
	rm -rf $(CTEX_DIR)
	mkdir -p $(CTEX_DIR)/doc/xelatex/ctex
	mkdir -p $(CTEX_DIR)/tex/xelatex/ctex/test
	cp ctex/README $(CTEX_DIR)
	cp ctex/*.sty ctex/*.cls $(CTEX_DIR)/tex/xelatex/ctex
	cp -r ctex/back ctex/cfg ctex/def ctex/engine ctex/fontset ctex/fd ctex/opt $(CTEX_DIR)/tex/xelatex/ctex
	cp ctex/test/*.tex $(CTEX_DIR)/tex/xelatex/ctex/test
	cp ctex/doc/ctex.pdf ctex/doc/ctex.tex $(CTEX_DIR)/doc/xelatex/ctex
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) ctex.zip ctex

clean:
	rm -rf $(BUILD_DIR)/*

