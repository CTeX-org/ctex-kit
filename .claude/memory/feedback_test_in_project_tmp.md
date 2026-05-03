---
name: 测试文件放在项目 ./tmp 目录
description: 临时测试文件应放在项目根目录的 ./tmp 下，不要放 /tmp
type: feedback
---

测试文件应在项目根目录的 `./tmp` 下创建，而非系统 `/tmp`。

**Why:** 保持测试文件与项目关联，方便查看和管理。

**How to apply:** 编写诊断/测试用 `.tex` 文件时，先 `mkdir -p ./tmp`，然后在项目根目录下直接诶操作。例如使用 `xelatex ./tmp/foo.tex -o ./tmp `；或者 `TEXINPUTS=./xeCJK/build/unpacked: xelatex ./tmp/foo.tex -o ./tmp`。
