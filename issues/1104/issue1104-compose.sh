#!/bin/sh
# 把三张 130 dpi 的整页图横向拼接，再附上第一行两端的 400 dpi 放大图。
# 需要先编译出 c-master.pdf、c-fs.pdf、c-fixed.pdf（见 issue1104-confirm.tex 开头）。
set -e
FONT=$(kpsewhich FandolSong-Regular.otf)
for f in c-master c-fs c-fixed; do
  pdftoppm -png -r 130 -singlefile $f.pdf $f
  pdftoppm -png -r 400 -singlefile $f.pdf hi-$f
  magick hi-$f.png -crop 270x200+60+215 +repage z0-$f.png
  magick hi-$f.png -crop 270x200+1400+215 +repage z1-$f.png
  magick z0-$f.png z1-$f.png -bordercolor '#999999' -border 1 +append -resize 540x z-$f.png
done
magick c-master.png c-fs.png c-fixed.png -bordercolor white -border 6x0 -background white +append top.png
magick z-c-master.png z-c-fs.png z-c-fixed.png -bordercolor white -border 7x0 -background white +append zrow.png
magick -size "$(magick identify -format %w top.png)x40" xc:white -font "$FONT" -pointsize 22 -fill '#333' \
  -gravity west -annotate +18+0 '第一行放大（400 dpi）：左为行首的 “，右为行尾的 —。红线是版心边界，字符越过红线的部分就是 microtype 的突出量。' cap.png
magick top.png cap.png zrow.png -background white -append -bordercolor white -border 0x8 \
  -bordercolor '#cccccc' -border 1 +repage -depth 8 issue1104-confirm.png
