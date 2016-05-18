#!/usr/bin/env texlua

-- zhmetrics-uptex v1.0
-- Copyright (C) 2016 by Leo Liu <leoliu.pku@gmail.com>

local fonts = {'serif', 'serifit', 'serifb', 'sans', 'sansb', 'mono'}
local pltopf = 'uppltotf -kanji=uptex'
local makejvf = 'makejvf -i -u gb'

for _, hv in pairs({'h', 'v'}) do
	for _, fnt in pairs(fonts) do
		local pl = string.format('upzhm-%s.pl', hv)
		local jfm = string.format('upzh%s-%s.tfm', fnt, hv)
		local vf = string.format('upzh%s-%s.vf', fnt, hv)
		local pstfm = string.format('up%s-%s.tfm', fnt, hv)
		os.execute(string.format('%s %s %s', pltopf, pl, jfm))
		os.execute(string.format('%s %s %s', makejvf, jfm, pstfm))
	end
end
