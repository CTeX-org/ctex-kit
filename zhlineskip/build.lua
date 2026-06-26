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
uploader            = "Ruixi Zhang"
maintainid          = "CTeX-org"
email               = "ruixizhang42@gmail.com"
repository          = "https://github.com/" .. maintainid .. "/ctex-kit"
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
supportdir          = "../supprot"
typesetexe          = "latexmk -pdfxe -xelatex"
typesetruns         = 1
uploadconfig  = {
  note              = "",
  announcement_file = "announcement.md",
  pkg               = module,
  version           = version .. " " .. date,
  author            = maintainer,
  uploader          = uploader,
  email             = email,
  summary           = summary,
  description       = description,
  license           = "lppl1.3c",
  ctanPath          = "/language/chinese/" .. module,
  home              = "http://ctex.org",
  bugtracker        = repository .. "/issues",
  support           = repository .. "/issues",
  repository        = repository,
  development       = "https://github.com/" .. maintainid,
  update            = true
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
function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
      cp(i, supportdir, localdir)
    end
  end
end
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
  cp(ctanreadme, unpackdir, currentdir)
  return 0
end
function tex(file,dir,cmd)
  dir = dir or "."
  cmd = cmd or typesetexe
  if os.getenv("WINDIR") ~= nil or os.getenv("COMSPEC") ~= nil then
    upretex_aux = "-usepretex=\"" .. typesetcmds .. "\""
    makeidx_aux = "-e \"$makeindex=q/makeindex -s " .. indexstyle .. " %O %S/\""
    sandbox_aux = "set \"TEXINPUTS=../local;%TEXINPUTS%;\" &&"
  else
    upretex_aux = "-usepretex=\'" .. typesetcmds .. "\'"
    makeidx_aux = "-e \'$makeindex=q/makeindex -s " .. indexstyle .. " %O %S/\'"
    sandbox_aux = "TEXINPUTS=\"../local:$(kpsewhich -var-value=TEXINPUTS):\""
  end
  return run(dir, sandbox_aux .. " " .. cmd         .. " " ..
                  upretex_aux .. " " .. makeidx_aux .. " " .. file)
end
