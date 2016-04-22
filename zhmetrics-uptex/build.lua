#!/usr/bin/env texlua

fonts = {'serif', 'serifit', 'serifb', 'sans', 'sansb', 'mono'}
pltopf = 'uppltotf -kanji=uptex'
makejvf = 'makejvf -i -u gb'


function unpack()
	lfs.mkdir('tfm')
	lfs.mkdir('vf')
	for _, hv in pairs({'h', 'v'}) do
		for _, fnt in pairs(fonts) do
			pl = string.format("upzhm-%s.pl", hv)
			jfm = string.format('upzh%s-%s.tfm', fnt, hv)
			vf = string.format('upzh%s-%s.vf', fnt, hv)
			pstfm = string.format('up%s-%s.tfm', fnt, hv)
			os.execute(string.format("%s %s %s", pltopf, pl, jfm))
			os.execute(string.format("%s %s %s", makejvf, jfm, pstfm))
			os.rename(jfm, 'tfm/' .. jfm)
			os.rename(vf, 'vf/' .. vf)
			os.rename(pstfm, 'tfm/' .. pstfm)
		end
	end
end

function tds()
	tfmdir = 'fonts/tfm/zhmetrics-uptex'
	vfdir = 'fonts/vf/zhmetrics-uptex'
	texdir = 'tex/uptex/zhmetrics-uptex'
	sourcedir = 'source/fonts/zhmetrics-uptex'
	docdir = 'doc/fonts/zhmetrics-uptex'
-- TODO
--	lfs.mkdir(tfmdir)
--	lfs.mkdir(vfdir)
--	lfs.mkdir(texdir)
--	lfs.mkdir(sourcedir)
--	lfs.mkdir(docdir)
end

function ctan()
	zipname = 'zhmetric-uptex.zip'
	os.execute('zip ' .. zipname .. ' README.md' ..
		' build.lua upzhm-h.pl upzhm-v.pl' ..
		' upzhfandolfonts.tex upzhfandolfonts-test.tex')
	os.execute('zip -r ' .. zipname .. ' tfm/ vf/')
end

function main(target)
	if target == "unpack" then
		unpack()
	elseif target == "tds" then
		tds()
	elseif target == "ctan" then
		unpack()
		ctan()
	else
		print("Usage: " .. arg[0] .. " [unpack]")
	end
end

if arg[1] then
	main(arg[1])
else
	main("ctan")
end
