ZIPFLAGS = -r
BUILD_DIR = build
ZIPS = $(BUILD_DIR)/CJKpunct.zip $(BUILD_DIR)/xeCJK.zip $(BUILD_DIR)/zhspacing.zip

all: $(ZIPS)

$(BUILD_DIR)/CJKpunct.zip: CJKpunct/README
	mkdir -p $(BUILD_DIR)
	zip $(ZIPFLAGS) $@ CJKpunct

$(BUILD_DIR)/xeCJK.zip: xecjk/README
	mkdir -p $(BUILD_DIR)
	zip $(ZIPFLAGS) $@ xecjk

$(BUILD_DIR)/zhspacing.zip: zhspacing/README
	rm -rf $(BUILD_DIR)/zhspacing
	mkdir -p $(BUILD_DIR)/zhspacing/doc/xetex/zhspacing
	cp zhspacing/README $(BUILD_DIR)/zhspacing
	cp zhspacing/doc/zhs-man.tex zhspacing/test/* $(BUILD_DIR)/zhspacing/doc/xetex/zhspacing
	cp -r zhspacing/tex $(BUILD_DIR)/zhspacing/tex
	cd $(BUILD_DIR) && zip $(ZIPFLAGS) zhspacing.zip zhspacing

clean:
	rm -f $(BUILD_DIR)/*

