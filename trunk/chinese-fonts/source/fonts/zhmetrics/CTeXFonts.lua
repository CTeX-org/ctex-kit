--  Copyright (C) 2009 Lingyun Wu
--  This file may be distributed and/or modified under the
--  conditions of the LaTeX Project Public License, either version 1.3
--  of this license or (at your option) any later version.
--  The latest version of this license is in
--    http://www.latex-project.org/lppl.txt
--  and version 1.3 or later is part of all distributions of LaTeX
--  version 2005/12/01 or later.

program = {
	name = "CTeXFonts",
	version = "v1.0",
	date = "2009/06/08",
}

-- default settings
settings = {
	-- options
	type1 = false,
	updmap = false,
	encoding = "GBK",
	cjkname = "song",
	cjkmap = "cjk",
	ttfdir = (os.getenv("SYSTEMROOT") or ".") .. [[\Fonts]],
	destdir = [[.\Fonts]],
	-- other settings
	slant = "sl",
}

settings.path = {
-- default path
	ttfontsmapdir = [[ttf2tfm\base]],
	cidxmapdir = [[fonts\map\dvipdfm\dvipdfmx]],
	cjkmapdir = [[fonts\map\chinese]],
	cjkttfmapdir = [[fonts\map\pdftex]],
	tfmdir = [[fonts\tfm\chinese]],
	afmdir = [[fonts\afm\chinese]],
	encdir = [[fonts\enc\chinese]],
	type1dir = [[fonts\type1\chinese]],
	cjkdir = [[tex\latex\CJK]],
	updmapdir = [[miktex\config]],
-- default filename
	ttfontsmapfile = "ttfonts.map",
	cidxmapfile = "cid-x.map",
	cjkttfmapfile = "cjk-ttf.map",
	updmapfile = "updmap.cfg",
}

-- settings for encoding
settings.gbk = {
	encoding = "GBK",
	prefix = "gbk",
	switches = "-L cugbk0.map+",
	dim = {10, 10},
	uenc = "UGBK",
	fdpre = "C19",
	fddir = "GB",
}
settings.utf8 = {
	encoding = "UTF8",
	prefix = "uni",
	switches = "-l plane+0x",
	dim = {16, 16},
	uenc = "Unicode",
	fdpre = "C70",
	fddir = "UTF8",
}
settings.big5 = {
	encoding = "Big5",
	prefix = "b5",
	switches = "-L cubig5.map+",
	dim = {6, 10},
	uenc = "UBig5",
	fdpre = "C00",
	fddir = "Bg5",
}

-- print verbose information
function printverbose(...)
	if settings.verbose then io.write(...) end
end

-- expand the variables in string
function expand(s, t)
	return (string.gsub(s, "%$(%w+)", t or settings))
end
expand_path = expand

-- replace default io.open
do
	local open = io.open
	io.open = function(f, m) return open(expand_path(f), m) end
end

-- execute command and hide console output
function exec(c)
	local f = io.popen(expand_path(c))
	local l = f:read("*a")
	f:close()
	return l
end

-- os dependent settings
if string.match(os.getenv("OS") or "", "^Windows") then
	-- test file or dir exist
	function file_exist(f)
		return os.execute([[if exist "]] .. expand_path(f) .. [[" exit 1]]) == 1
	end
	-- make dir
	function mkdir(d)
		exec([[if not exist "]] .. d .. [[" mkdir "]] .. d .. [["]])
	end
	-- move files
	function move(srcdir, srcfile, dest)
		exec([[move /Y "]] .. srcdir .. [["\]] .. srcfile .. [[ "]] .. dest .. [["]])
	end
else
	-- use texlive settings
	settings.texlive = true
	-- convert path to unix style
	function expand_path(s)
		return (string.gsub(expand(s), "\\", "/"))
	end
	-- test file or dir exist
	function file_exist(f)
		return os.execute([=[ [ -e "]=] .. expand_path(f) .. [=[" ] ]=]) == 0
	end
	-- make dir
	function mkdir(d)
		exec([=[ [ -e "]=] .. d .. [=[" ] || mkdir -p "]=] .. d .. [=["]=])
	end
	-- move files
	function move(srcdir, srcfile, dest)
		exec([[mv -f "]] .. srcdir .. [["\]] ..srcfile .. [[ "]] .. dest .. [["]])
	end
end

-- set metatable of settings
do
	local mt = {}
	mt.encoding = settings.gbk
	mt.__index = function (t, k)
		if mt.encoding[k] then
			return mt.encoding[k]
		elseif settings.path[k] then
			return settings.path[k]
		elseif program[k] then
			return program[k]
		end
		return nil
	end
	setmetatable(settings, mt)
end

-- display version
function show_version()
	local s = [[
$name $version ($date) Copyright (C) 2009 ctex.org
Automatically configure Chinese fonts for TeX.

This program comes with ABSOLUTELY NO WARRANTY.  This is free software, 
you are welcome to redistribute it under the terms of the GNU General 
Public License.

This program is written in Lua based on the perl script FontsGen written
by Instanton at ctex.org.

For help on usage of this program type $name -help or $name -h.
]]
	io.write(expand(s))
end

-- display usage
function show_usage()
	local s = [[

Usage:   $name [-options]
Avaliable options:

  [-encoding=...]         Set encoding of fonts. Supported encodings 
                          are GBK, UTF8 and Big5. Defaults to $encoding;
  [-prefix=...]           Prefix for CJK fonts. Defaults to gbk for GBK 
                          encoding, uni for UTF8 and b5 for Big5 encodings.  
                          Normally there is no need to reset this option;
  [-ttf=....ttf/c]        Specify name of the TrueType fonts;
  [-CJKname=...]          CJKfamily name of the generated fonts;
  [-cjkmap=...]           Base name of the .map file to be placed under
                          fonts\map. Defaults to be $cjkmap (corresponds to 
                          $cjkmap.map and $cjkmap_ttf.map);
  [-ttfdir=...]           Path to the TrueType fonts. Defaults to
                          $ttfdir;
  [-destdir=...]          Location of destination. Defaults to $destdir;
  [-stemv=...]            Add -v parameter into cid-x.map;
  [-Type1]                Force generating Type1 fonts. Will not generate 
                          Type1 fonts if omitted;
  [-updmap]               Add map file info into updmap.cfg file;
  [-texlive]              Change default settings for texlive
  [-overwrite]            Overwrite the existing entries in map files and
                          updmap.cfg with same cjk font name
  [-verbose]              Display more information in processing
  [-version|-v]           Version number and copyright infomation;
  [-help|-h]              Show this help text.
]]
	io.write(expand_path(s))
end

-- all valid options
valid_options = {}
-- options without value
valid_options[1] = {"type1", "updmap", "texlive", "overwrite", "verbose", "version", "v", "help", "h"}
-- options with value
valid_options[2] = {"encoding", "prefix", "ttf", "cjkname", "cjkmap", "ttfdir", "destdir", "stemv"}

-- parse options
args = {...}
args_valid = {}
for i, o in ipairs(valid_options) do
	for _, v in pairs(o) do
		args_valid[v] = i
	end
end
args_parsed = {}
for i = 1, #args do
	local k, v = string.match(args[i], "^%-(.-)=(.*)$")
	if not k then k = string.match(args[i], "^%-(.*)$") end
	if k then k = string.lower(k) end
	if not k or not args_valid[k] then
		io.write("Warning: Invalid option ", args[i], "\n")
	elseif args_parsed[k] then
		io.write("Warning: Duplicated option ", k, ", ignored\n")
	elseif args_valid[k] == 1 then
		if v then
			io.write("Warning: Option ", k, " do not need value, ignored\n")
		end
		args_parsed[k] = true
	else
		if not v then
			io.write("Error: Option ", k, " need a value\n")
			return
		end
		args_parsed[k] = v
	end
end

-- no option or version/help option
if #args < 1 then
	show_version()
	show_usage()
	return
elseif args_parsed.version or args_parsed.v then
	show_version()
	return
elseif args_parsed.help or args_parsed.h then
	show_usage()
	return
end

-- check options
for k, v in pairs(args_parsed) do
	settings[k] = v
end
printverbose("Checking options ...")

-- texlive settings
printverbose("...")
if settings.texlive then
	settings.path.ttfontsmapdir = [[fonts\map\ttf2pk\config]]
end

-- must provide ttf name
printverbose("...")
if not settings.ttf then
	io.write("Error: TrueType font name must be specified by -ttf option!\n")
	return
else
	local basename, suffix = string.match(settings.ttf, "^(.+)%.(.-)$")
	if not basename then
		settings.ttf = settings.ttf .. ".ttf"
	elseif basename and suffix == "" then
		settings.ttf = basename .. ".ttf"
	end
end
local f = io.open([[$ttfdir\$ttf]], "r")
if not f then
	io.write("Error: Can not open TrueType file ", expand_path([[$ttfdir\$ttf]]), "\n")
	return
else
	io.close(f)
end

-- stemv
printverbose("...")
if settings.stemv then
	local v = tonumber(settings.stemv)
	if not v then
		io.write("Warning: Stemv ", settings.stemv, " is not a valid number, ignored\n")
		settings.stemv = ""
	else
		settings.stemv = "-v " .. v
	end
else
	settings.stemv = ""
end

-- set enconding and default settings
printverbose("...")
local e = string.lower(settings.encoding)
if settings[e] then
	settings.encoding = settings[e].encoding
	getmetatable(settings).encoding = settings[e]
else
	io.write("Error: Invalid encoding ", settings.encoding, "\n")
	return
end

-- configure ranges
printverbose("...")
ranges = {'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
local r = {}
for i = 1, 2 do
	r[i] = {}
	for j = 1, settings.dim[i] do
		r[i][j] = ranges[j]
	end
end
settings.range1 = table.concat(r[1], ",")
settings.range2 = table.concat(r[2], ",")

printverbose(" OK\n")

-- show settings
if settings.verbose then
	io.write("Settings:\n")
	for k, v in pairs(settings) do
		if type(v) ~= "table" then
			io.write("\t", tostring(k), " = ")
			if type(v) == "string" then
				io.write('"', v, '"')
			else
				io.write(tostring(v))
			end
			io.write("\n")
		end
	end
end

-- make dirs
mkdir [[$destdir]]

-- generate tfm files
printverbose("Generating TFM files ...")
exec [[ttf2tfm "$ttfdir\$ttf" -q -f 0 "$destdir\$prefix$cjkname@$uenc@.tfm"]]
printverbose("...")
exec [[ttf2tfm "$ttfdir\$ttf" -q -f 0 -s 0.167 "$destdir\$prefix$cjkname$slant@$uenc@.tfm"]]
printverbose("...")
mkdir [[$destdir\$tfmdir\$prefix$cjkname]]
move([[$destdir]], [[*.tfm]], [[$destdir\$tfmdir\$prefix$cjkname]])
printverbose(" OK\n")

-- generate type1 files
if settings.type1 then
	printverbose("Generating Type1 files ...")
	local tfmfile = [[$destdir\$tfmdir\$prefix$cjkname\$prefix$cjkname$range1$range2.tfm]]
	for i = 1, settings.dim[1] do
		for j = 1, settings.dim[2] do
			settings.range1 = ranges[i]
			settings.range2 = ranges[j]
			if file_exist(tfmfile) then
				printverbose(".")
				exec [[ttf2pt1 -W0 -b -GFAE -pft $switches$range1$range2 "$ttfdir\$ttf" "$destdir\$prefix$cjkname$range1$range2"]]
			end
		end
	end

	printverbose("...")
	mkdir [[$destdir\$afmdir\$prefix$cjkname]]
	mkdir [[$destdir\$encdir\$prefix$cjkname]]
	mkdir [[$destdir\$type1dir\$prefix$cjkname]]
	move([[$destdir]], [[*.afm]], [[$destdir\$afmdir\$prefix$cjkname]])
	move([[$destdir]], [[*.enc]], [[$destdir\$encdir\$prefix$cjkname]])
	move([[$destdir]], [[*.pfb]], [[$destdir\$type1dir\$prefix$cjkname]])
	printverbose(" OK\n")
end

-- search and add lines to map files
function add_map_lines(filename, s_normal, s_slant)
	local add = {true, true}
	local f = io.open(filename, "r")
	local s = {}
	if f then
		for line in f:lines() do
			if string.match(line, "^%s*" .. settings.prefix .. settings.cjkname .. "%@") then
				add[1] = false
			elseif string.match(line, "^%s*" .. settings.prefix .. settings.cjkname .. settings.slant .. "%@") then
				add[2] = false
			else
				s[#s + 1] = line
			end
		end
		f:close()
		if settings.overwrite then
			f = io.open(filename, "w")
			if f then
				f:write(table.concat(s, "\n"), "\n")
				f:close()
				add = {true, true}
			end
		end
	end
	f = io.open(filename, "a")
	if f then
		f:seek("end")
		if add[1] then
			f:write(settings.prefix, settings.cjkname, "@", settings.uenc, "@ ", expand(s_normal), "\n")
		end
		if add[2] then
			f:write(settings.prefix, settings.cjkname, settings.slant, "@", settings.uenc, "@ ", expand(s_slant), "\n")
		end
		f:close()
	end
end

-- update ttfonts.map
printverbose("Updating ", settings.ttfontsmapfile, " ...")
mkdir [[$destdir\$ttfontsmapdir]]
add_map_lines([[$destdir\$ttfontsmapdir\$ttfontsmapfile]], "$ttf Pid=3 Eid=1", "$ttf Slant=0.167 Pid=3 Eid=1")
printverbose(" OK\n")

-- update cid-x.map
printverbose("Updating ", settings.cidxmapfile, " ...")
mkdir [[$destdir\$cidxmapdir]]
add_map_lines([[$destdir\$cidxmapdir\$cidxmapfile]], "unicode :0:$ttf $stemv", "unicode :0:$ttf -s .167 $stemv")
printverbose(" OK\n")

-- update cjk-ttf.map
printverbose("Updating ", settings.cjkttfmapfile, " ...")
mkdir [[$destdir\$cjkttfmapdir]]
add_map_lines([[$destdir\$cjkttfmapdir\$cjkttfmapfile]], "<$ttf PidEid=3,1", "<$ttf PidEid=3,1")
printverbose(" OK\n")

-- find psname
function find_psname()
	for i = 1, settings.dim[1] do
		for j = 1, settings.dim[2] do
			settings.range1 = ranges[i]
			settings.range2 = ranges[j]
			local f = io.open([[$destdir\$type1dir\$prefix$cjkname\$prefix$cjkname$range1$range2.pfb]], "r")
			if f then
				for line in f:lines() do
					local psname = string.match(line, "^/FontName /(.*)%-%x%x def$")
					if psname then
						settings.psname = psname
						f:close()
						return
					end
				end
				f:close()
			end
		end
	end
end

-- generate cjk type1 map file
if settings.type1 then
	printverbose("Updating ", settings.cjkmap, "-", settings.cjkname, ".map ...")
	find_psname()
	mkdir [[$destdir\$cjkmapdir]]
	local f = io.open([[$destdir\$cjkmapdir\$cjkmap-$cjkname.map]], "r")
	local s = {}
	if f then
		for line in f:lines() do
			if not string.match(line, "^%s*" .. settings.prefix .. settings.cjkname .. "%x%x%s+") and
			   not string.match(line, "^%s*" .. settings.prefix .. settings.cjkname .. settings.slant .. "%x%x%s+") and
			   not string.match(line, "^%s*$") then
				s[#s + 1] = line
			end
		end
		f:close()
	end
	f = io.open([[$destdir\$cjkmapdir\$cjkmap-$cjkname.map]], "w")
	if f then
		if #s > 0 then f:write(table.concat(s, "\n"), "\n") end
		for i = 1, settings.dim[1] do
			for j = 1, settings.dim[2] do
				settings.range1 = ranges[i]
				settings.range2 = ranges[j]
				if file_exist([[$destdir\$type1dir\$prefix$cjkname\$prefix$cjkname$range1$range2.pfb]]) then
					f:write(expand('$prefix$cjkname$range1$range2 $psname-$range1$range2 < $prefix$cjkname$range1$range2.pfb\n'))
					f:write(expand('$prefix$cjkname$slant$range1$range2 $psname-$range1$range2 " .167 SlantFont " < $prefix$cjkname$range1$range2.pfb\n'))
				end
			end
		end
		f:close()
	end
	printverbose(" OK\n")
end

-- generate fd file
printverbose("Generating fd file ...")
fdfile = [[
% This is the file $fdpre$cjkname.fd of the CJK package
%   for using Asian logographs (Chinese/Japanese/Korean) with LaTeX2e
%
% automatically generated by $name $version

\def\fileversion{4.8.2}
\def\filedate{$date}
\ProvidesFile{$fdpre$cjkname.fd}[\filedate\space\fileversion]

% Chinese characters
%
% character set: $encoding
% font encoding: CJK ($encoding)

\DeclareFontFamily{$fdpre}{$cjkname}{\hyphenchar \font\m@ne}

\DeclareFontShape{$fdpre}{$cjkname}{m}{n}{<-> CJK * $prefix$cjkname}{\CJKnormal}
\DeclareFontShape{$fdpre}{$cjkname}{b}{n}{<-> CJKb * $prefix$cjkname}{\CJKbold}
\DeclareFontShape{$fdpre}{$cjkname}{bx}{n}{<-> CJKb * $prefix$cjkname}{\CJKbold}
\DeclareFontShape{$fdpre}{$cjkname}{m}{it}{<-> CJK * $prefix$cjkname$slant}{\CJKnormal}
\DeclareFontShape{$fdpre}{$cjkname}{b}{it}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$cjkname}{bx}{it}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$cjkname}{m}{sl}{<-> CJK * $prefix$cjkname$slant}{\CJKnormal}
\DeclareFontShape{$fdpre}{$cjkname}{b}{sl}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$cjkname}{bx}{sl}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}

\endinput
]]

if settings.overwrite or not file_exist([[$destdir\$cjkdir\$fddir\$fdpre$cjkname.fd]]) then
	mkdir [[$destdir\$cjkdir\$fddir]]
	local f = io.open([[$destdir\$cjkdir\$fddir\$fdpre$cjkname.fd]], "w")
	if f then
		f:write(expand(fdfile))
		io.close(f)
	end
end
printverbose(" OK\n")

-- update updmap.cfg
function update_updmap()
	mkdir [[$destdir\$updmapdir]]
	local filename = [[$destdir\$updmapdir\$updmapfile]]
	local add = true
	local f = io.open(filename, "r")
	local s = {}
	if f then
		for line in f:lines() do
			line = string.lower(line)
			if string.match(line, "^%s*map%s*" .. settings.cjkmap .. "%-" .. settings.cjkname .. ".map") or
			   string.match(line, "^%s*mixedmap%s*" .. settings.cjkmap .. "%-" .. settings.cjkname .. ".map") or
			   string.match(line, "^%s*map%s*" .. settings.cjkmap .. "%-ttf.map") or
			   string.match(line, "^%s*mixedmap%s*" .. settings.cjkmap .. "%-ttf.map") then
				add = false
			else
				s[#s + 1] = line
			end
		end
		f:close()
		if settings.overwrite then
			f = io.open(filename, "w")
			if f then
				f:write(table.concat(s, "\n"), "\n")
				f:close()
				add = {true, true}
			end
		end
	end
	f = io.open(filename, "a")
	if f then
		f:seek("end")
		if add then
			if settings.type1 then
				f:write("Map ", settings.cjkmap, "-", settings.cjkname, ".map\n")
			else
				f:write("Map ", settings.cjkmap, "-ttf.map\n")
			end
		end
		f:close()
	end
end

if settings.updmap then
	printverbose("Updating updmap config ...")
	if settings.texlive then
		if settings.type1 then
			exec [[updmap-sys --enable Map=$cjkmap-$cjkname.map]]
			exec [[updmap --enable Map=$cjkmap-$cjkname.map]]
		else
			exec [[updmap-sys --enable Map=$cjkmap-ttf.map]]
			exec [[updmap --enable Map=$cjkmap-ttf.map]]
		end
	else
		update_updmap()
	end
	printverbose(" OK\n")
end
