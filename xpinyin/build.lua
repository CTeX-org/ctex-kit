#!/usr/bin/env texlua

module = 'xpinyin'

packtdszip = true

sourcefiles = {'xpinyin.dtx'}
unpackfiles = {'xpinyin.dtx'}
unpacksuppfiles = {'xpinyin.ver'}
installfiles = {'*.sty', '*.def'}
unpackexe = 'luatex'
typesetexe = 'xelatex'

function copytds_posthook()
  -- ins 文件
  cp('xpinyin.ins', unpackdir, tdsdir .. '/source/' .. moduledir)
end

dofile('../tool/zhl3build.lua')

-- vim:sw=2:et
