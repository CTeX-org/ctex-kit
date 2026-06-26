--[==========================================================================[--
    L3BUILD FILE FOR ZHLINESKIP                  Copyright (C) by Ruixi Zhang
--]==========================================================================]--

--[==========================================================================[--
    Basic Information: Do Check Before Push
--]==========================================================================]--
module              = "zhlineskip"
version             = "v1.0f"
date                = "2026-06-27"
maintainer          = "Ruixi Zhang"
email               = "ruixizhang42@gmail.com"
summary             = "Line spacing for CJK documents"
description         = "This package supports typesetting CJK documents. It allows users to specify the two ratios between the leading and the font size of the body text and the footnote text. For CJK typesetting, these ratios usually range from 1.5 to 1.67. This package is also capable of restoring the math leading to that of the Latin text (usually 1.2 times the font size). Finally, it is possible to achieve the `Microsoft Word` multiple line spacing style using `zhlineskip`."

--[==========================================================================[--
    Configuration: Check, Tag, Pack, Upload     Do NOT Modify if Unnecessary
--]==========================================================================]--
checkengines        = {"pdftex"}
checkruns           = 1
cleanfiles          = {"*.log", "*.pdf", "*.zip", "*.curlopt"}
ctanzip             = module
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
    content = string.gsub(content,
      "%%<++!driver>\\GetIdInfo $Id: " .. module .. ".dtx " ..
      "v%d+%.%d+%w %d+%-%d+%-%d+ (.-)<(.-)>",
      "%%<+!driver>\\GetIdInfo $Id: "  .. module .. ".dtx " ..
      tagname .. " " .. tagdate .. " " .. maintainer .. "<" .. email .. ">")
  end
  return content
end

--[================== "Hacks" to `l3build` | Do not Modify ==================]--
function fetchdocsupp(shortlink)
  run(typesetdir, "curl -O -L \"https://" .. shortlink .. "\"")
  return 0
end
function docinit_hook()
  local notofontset = {
    "SerifCJKsc-Medium", "SerifCJKsc-Bold", "SerifCJKsc-Black",
    "SansCJKsc-Regular", "SansCJKsc-Bold"
  }
  for _, series in pairs(notofontset) do
    fetchdocsupp(
      "mirrors.ctan.org/fonts/notocjksc/Noto" .. series .. ".otf")
  end
  for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
    cp(i, supportdir, localdir)
  end
  cp(ctanreadme, unpackdir, currentdir)
  return 0
end
