--[==========================================================================[--
    L3BUILD FILE FOR ZHLINESKIP                  Copyright (C) by Ruixi Zhang
--]==========================================================================]--

--[==========================================================================[--
    Basic Information: Do Check Before Push

    version + date 是 release 的"事实源". l3build tag 流程会用这俩值回写
    .dtx 里 `%<+!driver>\GetIdInfo $Id: zhlineskip.dtx vX.Yz YYYY-MM-DD ...$`
    (见下方 update_tag 函数), 所以发新版只需改这里两行 + 在 .dtx 里写
    `\changes` 记录, 不必手动碰 .dtx 的 GetIdInfo 行.
--]==========================================================================]--
module              = "zhlineskip"
version             = "v1.0g"
date                = "2026-07-07"
maintainer          = "Mingyu Xia"
email               = "myhsia@outlook.com"
summary             = "Line spacing for CJK documents"
description         = "This package supports typesetting CJK documents. It allows users to specify the two ratios between the leading and the font size of the body text and the footnote text. For CJK typesetting, these ratios usually range from 1.5 to 1.67. This package is also capable of restoring the math leading to that of the Latin text (usually 1.2 times the font size). Finally, it is possible to achieve the `Microsoft Word` multiple line spacing style using `zhlineskip`."

--[==========================================================================[--
    Configuration: Check, Tag, Pack, Upload     Do NOT Modify if Unnecessary
--]==========================================================================]--
checkengines        = {"pdftex"}
checkruns           = 1
cleanfiles          = {"*.log", "*.pdf", "*.zip", "*.curlopt"}
-- ctanzip 不显式设, 走 l3build 默认 (= module .. "-ctan"), 跟 ctex/xeCJK 等
-- 对齐. release.yml 的 Prepare release asset step 期望 zhlineskip-ctan.zip.
demofiles           = {module .. "-test.tex"}
excludefiles        = {"*~"}
installfiles        = {module .. ".sty", module .. ".ins"}
sourcefiles         = {module .. ".dtx", "*.pdf"}
textfiles           = {"README.md", "*.lua"}
unpackfiles         = {module .. ".dtx"}
stdengine           = "pdftex"
supportdir          = "../support/"
typesetexe          = "xelatex"
dofile(supportdir .. "build-config.lua")

-- CTAN upload 走 release-ctan-upload.yml workflow 触发. uploader / email
-- 不在 build.lua 硬编码, 由 workflow 通过 CTAN_UPLOADER / CTAN_EMAIL
-- 环境变量注入, 避免任何 clone 仓库的人直接 l3build upload 冒名提交.
uploadconfig = ctex_kit_uploadconfig {
  pkg         = module,
  version     = version .. " " .. date,
  author      = maintainer,
  summary     = summary,
  description = description,
  ctanPath    = "/language/chinese/" .. module,
}

function update_tag(file, content, tagname, tagdate)
  tagname = version
  tagdate = date
  if string.match(file, module .. ".dtx$") then
    -- 匹配 .dtx 里的 `%<+!driver>\GetIdInfo $Id: zhlineskip.dtx vX.Yz YYYY-MM-DD ...<...>`
    -- 把 `vX.Yz YYYY-MM-DD` 和后面的 `<...>` 替换成 build.lua 的 version/date/maintainer/email.
    -- Lua pattern 注意点:
    --   `%%`    -> 字面 `%`
    --   `%<`    -> 字面 `<`
    --   `%+`    -> 字面 `+`         (+ 在 Lua 是量词, 这里要字面所以转义)
    --   `(.-)`  -> 最短匹配捕获组 (Author 名)
    --   `<(.-)>`-> 捕获 email
    content = string.gsub(content,
      "%%<%+!driver>\\GetIdInfo $Id: " .. module .. ".dtx " ..
      "v%d+%.%d+%w %d+%-%d+%-%d+ (.-)<(.-)>",
      "%%<+!driver>\\GetIdInfo $Id: "  .. module .. ".dtx " ..
      tagname .. " " .. tagdate .. " " .. maintainer .. "<" .. email .. ">")
  end
  return content
end

--[================== "Hacks" to `l3build` | Do not Modify ==================]--
-- docinit_hook 在 typeset 前给 build/local 准备额外文件:
--   1. ctxdoc.cls / ctxdocstrip.tex / ctex-zhconv*.lua 来自 ../support/
--      (跟 ctex/xeCJK 一样, 用 ctex-kit 的 ctxdoc 排版类)
--   2. README.md cp 到包根目录, l3build ctan 打包 zip 时要带上
--
-- 不再从 mirrors.ctan.org 下载 Noto CJK 字体: zhlineskip.dtx driver 部分已
-- 跟 xeCJK 对齐用 fontconfig 风格字体名 (`Noto Serif CJK SC` 而非
-- `NotoSerifCJKsc-Medium.otf`), 走系统 fontconfig 查找. CI 上 release.yml
-- 的 "Install CJK fonts" step 已 fontfetch + fc-cache; 本地开发需自行装
-- Noto CJK (Debian: `fonts-noto-cjk`; mac: `brew install --cask
-- font-noto-serif-cjk-sc font-noto-sans-cjk-sc`).
function docinit_hook()
  for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
    cp(i, supportdir, localdir)
  end
  -- ctanreadme 是 support/build-config.lua 里设的默认值 ("README.md"),
  -- 此处隐式继承. 不在 build.lua 单独覆写, 跟其他包 (ctex/xeCJK) 保持一致.
  cp(ctanreadme, unpackdir, currentdir)
  return 0
end
