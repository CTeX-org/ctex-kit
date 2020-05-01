
module = "xpinyin"

packtdszip = true

sourcefiles      = {"xpinyin.dtx", "xpinyin.ins"}
unpackfiles      = {"xpinyin.ins"}
gitverfiles      = {"xpinyin.dtx"}
installfiles     = {"*.sty", "*.def", "*.ins"}
unpacksuppfiles  = {"xpinyin.id", "xpinyin.db", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "source/latex/xpinyin/*.ins",
}

function unpack_prehook()
  cleandir(unpackdir)
  cp("ctxdocstrip.tex",  supportdir, currentdir)
  os.execute(unpackexe .. " -output-directory=" .. unpackdir .." xpinyin.dtx > " .. os_null)
  rmfile(".", "ctxdocstrip.tex")
  cp("xpinyin.ins", unpackdir, currentdir)
  cp("xpinyin.lua", unpackdir, supportdir)
  run(supportdir, "texlua xpinyin.lua")
end

function unpack_posthook()
  rmfile(currentdir, "ctxdocstrip.tex")
  rmfile(currentdir, "xpinyin.ins")
end

dofile("../support/build-config.lua")
