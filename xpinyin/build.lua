#!/usr/bin/env texlua

module = 'xpinyin'

packtdszip = true

sourcefiles = {'xpinyin.dtx'}
unpackfiles = {'xpinyin.dtx'}
installfiles = {'*.sty', '*.def'}
cleanfiles = {'*.ver', '*.pdf', '*.log', 'xpinyin.db', 'xpinyin.zip'}
unpackexe = 'luatex'
typesetexe = 'xelatex'

function copytds_posthook()
  -- ins 文件
  cp('xpinyin.ins', unpackdir, tdsdir .. '/source/latex/xpinyin')
end

dofile('../tool/zhl3build.lua')

-- vim:sw=2:et
