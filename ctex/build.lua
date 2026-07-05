
module = "ctex"

packtdszip = true

sourcefiles      = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles      = {"ctex.dtx"}
installfiles     = {"*.sty", "*.cls", "*.clo", "*.def", "*.cfg", "*.fd", "ct*.tex", "zh*.tex", "*.dict", "*.ins", "*.lua"}
unpacksuppfiles  = {"ctex.id", "ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-index.lua"}
typesetsuppfiles = {"ctxdoc.cls"}
gitverfiles      = {"ctex.dtx", "ctxdoc.cls"}

-- 手册排版依赖本仓库的 xeCJK (PoZheHaoLigature 等新特性)。
-- dep_install 只把产物放进 dep 自己的 build/local, kpse 搜不到,
-- 需要仿照 checkinit_hook 手动复制进本包的 localdir。
typesetdeps = {"../xeCJK"}

docinit_hook = function()
  for _,i in ipairs(typesetdeps) do
    local dep_unpackdir = i .. "/" .. unpackdir
    cp("*.sty", dep_unpackdir, localdir)
  end
  return 0
end

tdslocations = {
  "source/latex/ctex/*-make.lua",
  "source/latex/ctex/*.ins",
  "tex/generic/ctex/zhmap/ctex-zhmap*.tex",
  "tex/generic/ctex/*.tex",
  "tex/latex/ctex/config/*.cfg",
  "tex/latex/ctex/fd/*.fd",
  "tex/latex/ctex/engine/ctex-engine-*.def",
  "tex/latex/ctex/fontset/ctex-fontset-*.def",
  "tex/latex/ctex/heading/ctex-heading-*.def",
  "tex/latex/ctex/scheme/ctex-scheme-*.def",
  "tex/latex/ctex/dictionary/*.dict",
  "tex/luatex/ctex/*.lua",
}

function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
      cp(i, supportdir, unpackdir)
    end
  end
end

function copyctan_posthook()
  local dest = ctandir .. "/" .. ctanpkg
  for _,file in ipairs{"ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-make.lua"} do
    cp(file, unpackdir, dest)
  end
end

testfiledir    = "./test/testfiles"
testsuppdir    = "./test/support"
testdir        = "./build/check"
checkruns      = 2
stdengine      = "xetex"
checkdeps      = {"../xeCJK","../zhnumber"}
checkengines   = {"pdftex", "xetex", "luatex", "uptex"}
specialformats = {}
specialformats.latex = {
  pdftex = {format = "latex"},
  uptex  = {binary = "euptex"}
}

-- unfortunately cleveref is incompatible with recent LaTeX2e
excludetests   = {
  "cleveref02",
  "cleveref03",
}

checkinit_hook = function()
  for _,i in ipairs(checkdeps) do
    local unpackdir = i .. "/" .. unpackdir
    for _,i in ipairs(installfiles) do
      cp(i, unpackdir, testdir)
    end
  end
  return 0
end

dofile("../support/build-config.lua")

-- ── CTAN upload (用 release-ctan-upload.yml workflow 触发) ────────────────
-- 版本号从 ctex.dtx 的 `\ExplFileDate` 动态读取, 避免与 .dtx 失同步.
-- uploader/email 不在此填, 由 workflow 在 `l3build upload` 命令行注入.
uploadconfig = ctex_kit_uploadconfig {
  pkg         = "ctex",
  version     = read_dtx_version("ctex.dtx"),
  author      = "Leo Liu; Qing Lee; Liam Huang",
  summary     = "LaTeX classes and packages for Chinese typesetting",
  description = "ctex is a bundle of LaTeX classes and packages for "
             .. "typesetting documents in Chinese. It works with the "
             .. "(pdf)LaTeX, XeLaTeX and LuaLaTeX engines, supports "
             .. "GB2312 / UTF-8 / Unicode input, integrates Chinese "
             .. "punctuation kerning, multi-engine font configuration, "
             .. "and provides Chinese-style section heading commands "
             .. "for the standard article / book / report classes.",
  ctanPath    = "/language/chinese/ctex",
}
