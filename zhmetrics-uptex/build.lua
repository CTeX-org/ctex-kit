#!/usr/bin/env texlua

dirs = {'h', 'v'}
fonts = {'serif', 'serifit', 'serifb', 'sans', 'sansb', 'mono'}
pltopf = 'uppltotf -kanji=uptex'
makejvf = 'makejvf -i -u gb'

for _, hv in pairs(dirs) do
	for _, fnt in pairs(fonts) do
		pl = string.format("upzhm-%s.pl", hv)
		jfm = string.format('upzh%s-%s.tfm', fnt, hv)
		pstfm = string.format('up%s-%s.tfm', fnt, hv)
		os.execute(string.format("%s %s %s", pltopf, pl, jfm))
		os.execute(string.format("%s %s %s", makejvf, jfm, pstfm))
	end
end
