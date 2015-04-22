#!/usr/bin/env texlua

module = 'xpinyin'

packtdszip = true

sourcefiles = {'xpinyin.dtx', 'xpinyin.ins'}
unpackfiles = {'xpinyin.dtx'}
installfiles = {'*.sty', '*.def'}
cleanfiles = {'*.ver', '*.pdf', '*.log', 'xpinyin.db', 'xpinyin.zip'}
unpackexe = 'luatex'
typesetexe = 'xelatex'

dofile('../tool/zhl3build.lua')

-- vim:sw=2:et
