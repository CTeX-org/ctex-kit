"use strict";
// 只转换 OI Wiki 首页 docs/index.md，管线与参数照抄 oi-wiki-export/index.js 的 convertMarkdown。
// depth=2：mkdocs.yml 中 index.md 位于 nav 第一层（简介）之下，exportRecursive 以 depth+1 调用。
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkMath from "remark-math";
import remarkDetails from "remark-details";
import remarkGfm from "remark-gfm";
import { latex } from "remark-latex";
import remarkFootnotes from "remark-footnotes";
import { read, writeSync } from "to-vfile";
import { join } from "path";
import remarkTabbed from "remark-tabbed";
import { mkdirSync, existsSync } from "fs";

const prefixRegEx = /[^a-zA-Z0-9]/gi;
const oiwikiRoot = process.argv[2];
const filename = join(oiwikiRoot, "docs", "index.md");
for (const d of ["tex", "images"]) if (!existsSync(d)) mkdirSync(d);
unified()
  .use(remarkParse)
  .use(remarkMath)
  .use(remarkGfm)
  .use(remarkDetails)
  .use(remarkTabbed)
  .use(remarkFootnotes)
  .use(latex, {
    prefix: filename.replace(prefixRegEx, "").replace(/md$/, ""),
    depth: 2,
    current: filename,
    root: join(oiwikiRoot, "docs"),
    nested: false,
    forceEscape: false,
    path: filename.replace(/\.md$/, "/"),
  })
  .process(await read(filename), function (err, file) {
    if (err) throw err;
    file.dirname = "tex";
    file.stem = filename.replace(prefixRegEx, "");
    file.extname = ".tex";
    writeSync(file);
    console.log("wrote tex/" + file.stem + ".tex");
  });
