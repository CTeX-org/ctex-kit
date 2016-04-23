#!/usr/bin/env texlua

-- zhmetrics-uptex v1.0
-- Copyright (C) 2016 by Leo Liu <leoliu.pku@gmail.com>

local fonts = {'serif', 'serifit', 'serifb', 'sans', 'sansb', 'mono'}
local pltopf = 'uppltotf -kanji=uptex'
local makejvf = 'makejvf -i -u gb'

function copyfile(path_src, path_dst)
	local cp = 'cp -f'
	if os.type == 'windows' then
		cp = 'copy /y'
		path_src = path_src:gsub('/', '\\')
		path_dst = path_dst:gsub('/', '\\')
	end
	os.execute(cp .. ' ' .. path_src .. ' ' .. path_dst)
end

function move(path_src, path_dst)
	local mv = 'mv -f'
	if os.type == 'windows' then
		mv = 'move /y'
		path_src = path_src:gsub('/', '\\')
		path_dst = path_dst:gsub('/', '\\')
	end
	os.execute(mv .. ' ' .. path_src .. ' ' .. path_dst)
end

function mkdir(dir)
	if lfs.attributes(dir) ~= nil then
		do return end
	end
	local md = 'mkdir -p'
	if os.type == 'windows' then
		md = 'mkdir'
		dir = dir:gsub('/', '\\')
	end
	os.execute(md .. ' ' .. dir)
end

function rmdir(dir)
	if lfs.attributes(dir) == nil then
		do return end
	end
	local rd = 'rm -r -f'
	if os.type == windows then
		rd = 'rmdir /s /q'
		dir = dir:gsub('/', '\\')
	end
	os.execute(rd .. ' ' .. dir)
end

function unpack()
	mkdir('tfm')
	mkdir('vf')
	for _, hv in pairs({'h', 'v'}) do
		for _, fnt in pairs(fonts) do
			local pl = string.format("upzhm-%s.pl", hv)
			local jfm = string.format('upzh%s-%s.tfm', fnt, hv)
			local vf = string.format('upzh%s-%s.vf', fnt, hv)
			local pstfm = string.format('up%s-%s.tfm', fnt, hv)
			os.execute(string.format("%s %s %s", pltopf, pl, jfm))
			os.execute(string.format("%s %s %s", makejvf, jfm, pstfm))
			move(jfm, 'tfm/' .. jfm)
			move(vf, 'vf/' .. vf)
			move(pstfm, 'tfm/' .. pstfm)
		end
	end
end

function tds()
	local tfmdir = 'tds/fonts/tfm/zhmetrics-uptex'
	local vfdir = 'tds/fonts/vf/zhmetrics-uptex'
	local texdir = 'tds/tex/uptex/zhmetrics-uptex'
	local sourcedir = 'tds/source/fonts/zhmetrics-uptex'
	local docdir = 'tds/doc/fonts/zhmetrics-uptex'
	mkdir(tfmdir)
	mkdir(vfdir)
	mkdir(texdir)
	mkdir(sourcedir)
	mkdir(docdir)
	for _, hv in pairs({'h', 'v'}) do
		for _, fnt in pairs(fonts) do
			local jfm = string.format('upzh%s-%s.tfm', fnt, hv)
			local vf = string.format('upzh%s-%s.vf', fnt, hv)
			local pstfm = string.format('up%s-%s.tfm', fnt, hv)
			copyfile('tfm/' .. jfm, tfmdir .. '/' .. jfm)
			copyfile('tfm/' .. pstfm, tfmdir .. '/' .. pstfm)
			copyfile('vf/' .. vf, vfdir .. '/' .. vf)
		end
		local pl = string.format("upzhm-%s.pl", hv)
		copyfile(pl, sourcedir .. '/' .. pl)
	end
	copyfile('build.lua', sourcedir .. '/build.lua')
	copyfile('upzhfandolfonts.tex', texdir .. '/upzhfandolfonts.tex')
	copyfile('README.md', docdir .. '/README.md')
	copyfile('upzhfandolfonts-test.tex', docdir .. '/upzhfandolfonts-test.tex')
	local tdszipname = 'zhmetrics-uptex.tds.zip'
	lfs.chdir('tds')
	os.execute('zip -r ' .. '../' .. tdszipname .. ' *')
end

function ctan()
	local zipname = 'zhmetrics-uptex.zip'
	os.execute('zip ' .. zipname .. ' README.md' ..
		' build.lua upzhm-h.pl upzhm-v.pl' ..
		' upzhfandolfonts.tex upzhfandolfonts-test.tex')
	os.execute('zip -r ' .. zipname .. ' tfm/ vf/')
end

function clean()
	rmdir('tds')
	rmdir('tfm')
	rmdir('vf')
	os.remove('zhmetrics-uptex.zip')
	os.remove('zhmetrics-uptex.tds.zip')
end

function main(target)
	if target == "unpack" then
		unpack()
	elseif target == "tds" then
		unpack()
		tds()
	elseif target == "ctan" then
		unpack()
		ctan()
	elseif target == "clean" then
		clean()
	else
		print("Usage: " .. arg[0] .. " [unpack|tds|ctan|clean]")
	end
end

main(arg[1])
