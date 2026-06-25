module              = "zhlineskip"

sourcefiles         = {module .. ".dtx", "*.pdf"}
installfiles        = {module .. ".sty", module .. ".ins"}
demofiles           = {module .. "-*-test.tex"}
unpackfiles         = {module .. ".dtx"}

stdengine           = "pdftex"
checkengines        = {"pdftex"}
checkruns           = 1

function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
      cp(i, supportdir, localdir)
    end
  end
end
function docinit_hook()
  -- run(typesetdir, "curl -O -L " ..)
  cp(ctanreadme, unpackdir, currentdir)
  return 0
end

dofile("../support/build-config.lua")
