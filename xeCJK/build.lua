#!/usr/bin/env texlua

module = 'xeCJK'

packtdszip = true

sourcefiles = {'xeCJK.dtx'}
unpackfiles = {'xeCJK.dtx'}
unpacksuppfiles = {'xeCJK.ver'}
typesetfiles = {'xeCJK.dtx', 'xunicode-symbols.tex'}
typesetsuppfiles = {'UnicodeData.txt'}
installfiles = {'*.sty', '*.cfg', '*.def'}
unpackexe = 'xetex'
typesetexe = 'xelatex'
makeindexexe = 'zhmakeindex'

subtexdirs = {
  ['config'] = '*.cfg',
}

-- 下载 UnicodeData.txt，并准备 xunicode-symbols.tex
function doc_prehook()
  mkdir(supportdir)
  if not lfs.isfile(supportdir .. '/UnicodeData.txt') then
    local unicode_data = assert(socket.http.request(
      'http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt'),
      'download failed')
    local f = assert(io.open(supportdir .. '/UnicodeData.txt', 'wb'), 'UnicodeData.txt not writable')
    f:write(unicode_data)
    f:close()
  end
  cp('xunicode-symbols.tex', unpackdir, maindir)
end

function doc_posthook()
  os.remove(maindir .. '/xunicode-symbols.tex')
end

function copytds_posthook()
  -- 字符映射文件
  local mapdir = tdsdir .. '/fonts/misc/xetex/fontmapping/xeCJK'
  mkdir(mapdir)
  cp('*.map', './map', mapdir)
  cp('*.tec', './map', mapdir)
  -- 示例
  local exampledir = tdsdir .. '/doc/latex/xeCJK/example'
  mkdir(exampledir)
  cp('xeCJK-example-*.tex', unpackdir, exampledir)
  -- ins 文件
  cp('xeCJK.ins', unpackdir, tdsdir .. '/source/latex/xeCJK')
end

dofile('../tool/zhl3build.lua')

-- vim:sw=2:et
