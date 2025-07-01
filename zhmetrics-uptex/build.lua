#!/usr/bin/env texlua

-- zhmetrics-uptex v1.0
-- Copyright (C) 2016 by Leo Liu <leoliu.pku@gmail.com>

local fonts = {'serif', 'serifit', 'serifb', 'sans', 'sansb', 'mono'}

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
	if lfs.attributes(dir) then
		return
	end
	local md = 'mkdir -p'
	if os.type == 'windows' then
		md = 'mkdir'
		dir = dir:gsub('/', '\\')
	end
	os.execute(md .. ' ' .. dir)
end

function rmdir(dir)
	if not lfs.attributes(dir) then
		return
	end
	local rd = 'rm -r -f'
	if os.type == 'windows' then
		rd = 'rmdir /s /q'
		dir = dir:gsub('/', '\\')
	end
	os.execute(rd .. ' ' .. dir)
end

function packfiles(zipname, workdir, tfmdir, vfdir, texdir, sourcedir, docdir)
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
			copyfile(jfm, tfmdir .. '/')
			copyfile(pstfm, tfmdir .. '/')
			copyfile(vf, vfdir .. '/')
		end
		local pl = string.format('upzhm-%s.pl', hv)
		copyfile(pl, sourcedir .. '/')
	end
	copyfile('makemetrics.lua', sourcedir .. '/')
	copyfile('upzhfandolfonts.tex', texdir .. '/')
	copyfile('README.md', docdir .. '/')
	copyfile('upzhfandolfonts-test.tex', docdir .. '/')
	copyfile('upzhfandolfonts-test.pdf', docdir .. '/')
	local tdszipname = 'zhmetrics-uptex.tds.zip'
	if lfs.attributes(zipname) then
		os.remove(zipname)
	end
	local curdir = lfs.currentdir()
	lfs.chdir(workdir)
	os.execute('zip -r ' .. curdir .. '/' .. zipname .. ' *')
	lfs.chdir(curdir)
end

function tds()
	packfiles('zhmetrics-uptex.tds.zip', 'tds',
		'tds/fonts/tfm/zhmetrics-uptex',
		'tds/fonts/vf/zhmetrics-uptex',
		'tds/tex/uptex/zhmetrics-uptex',
		'tds/source/fonts/zhmetrics-uptex',
		'tds/doc/fonts/zhmetrics-uptex')
end

function ctan()
	packfiles('zhmetrics-uptex.zip', 'ctan',
		'ctan/tfm',
		'ctan/vf',
		'ctan/tex',
		'ctan/source',
		'ctan/doc')
	copyfile('README.md', 'ctan/')
	os.execute('zip zhmetrics-uptex.zip README.md')
end

function clean()
	for _, hv in pairs({'h', 'v'}) do
		for _, fnt in pairs(fonts) do
			local jfm = string.format('upzh%s-%s.tfm', fnt, hv)
			local vf = string.format('upzh%s-%s.vf', fnt, hv)
			local pstfm = string.format('up%s-%s.tfm', fnt, hv)
			os.remove(jfm)
			os.remove(vf)
			os.remove(pstfm)
		end
	end
	rmdir('tds')
	rmdir('ctan')
end

function main(target)
	local unpack = function()
		dofile('makemetrics.lua')
		os.execute('uplatex upzhfandolfonts-test')
		os.execute('dvipdfmx upzhfandolfonts-test')
		for _, suf in pairs({'.aux', '.log', '.dvi'}) do
			os.remove('upzhfandolfonts-test' .. suf)
		end
	end
	if target == 'unpack' then
		unpack()
	elseif target == 'tds' then
		unpack()
		tds()
	elseif target == 'ctan' then
		unpack()
		ctan()
	elseif target == 'clean' then
		clean()
	else
		print('Usage: ' .. arg[0] .. ' [unpack|tds|ctan|clean]')
	end
end

main(arg[1])
