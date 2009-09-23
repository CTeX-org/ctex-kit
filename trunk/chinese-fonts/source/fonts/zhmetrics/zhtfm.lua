--  Copyright (C) 2009 Lingyun Wu
--  This file may be distributed and/or modified under the
--  conditions of the LaTeX Project Public License, either version 1.3
--  of this license or (at your option) any later version.
--  The latest version of this license is in
--    http://www.latex-project.org/lppl.txt
--  and version 1.3 or later is part of all distributions of LaTeX
--  version 2005/12/01 or later.


-- global settings
settings = {
	tfmdir = [[fonts\tfm\chinese]],
	use_slant = false,
}

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

-- template for pl files
pl_template = {
	char = [[
(CHARACTER D $cid
    (CHARWD R 1.0)
    (CHARHT R 0.8)
    (CHARDP R 0.1)
    )
]],
	header = [[
(FAMILY $familyname$sid)
(CODINGSCHEME CJK-$encoding)
(DESIGNSIZE R 10.0)
(CHECKSUM O 0)
(FONTDIMEN
    (SLANT R $slant)
    (SPACE R 1.0)
    (STRETCH R 0.3)
    (SHRINK R 0.1)
    (XHEIGHT R 0.4)
    (QUAD R 1.0)
    )
]],
}

function pl_charset ()
	local charset = {}
	for cid = 0, 255 do
		charset[#charset + 1] = (string.gsub(pl_template.char, "%$cid", cid))
	end
	return table.concat(charset)
end

pl_template.charset = pl_charset()

function write_tfm (path, familyname, encoding, slant)
	settings.familyname = string.upper(familyname)
	settings.encoding = string.upper(encoding)
	if settings.use_slant then
		settings.slant = slant or 0.0
	else
		settings.slant = 0.0
	end
	if settings.encoding == "UGBK" then
		settings.max_sid = 94
		settings.format = "%02d"
	elseif settings.encoding == "UNICODE" then
		settings.max_sid = 255
		settings.format = "%02x"
	else
		print("Error: Unknown encoding!")
		exit(1)
	end
	mkdir(path)
	for sid = 0, settings.max_sid do
		settings.sid = string.format(settings.format, sid)
		settings.filename = path .. "\\" .. string.lower(expand("$familyname$sid"))
		local s = string.gsub(pl_template.header, "%$(%w+)", settings) .. pl_template.charset
		local f = io.open("$filename.pl", "w")
		print(settings.filename)
		f:write(s)
		f:close()
		exec([[pltotf "]] .. "$filename.pl" .. [[" "]] .. "$filename.tfm" .. [["]])
		os.remove(expand_path("$filename.pl"))
	end
end

function generate_tfm (cjkname)
	local familyname = "gbk" .. string.lower(cjkname)
	local path = settings.tfmdir .. "\\" .. familyname
	write_tfm(path, familyname, "UGBK")
	write_tfm(path, familyname .. "sl", "UGBK", 0.167)
	familyname = "uni" .. string.lower(cjkname)
        if (cjkname == "") then familyname = "cyberb" end
	path = settings.tfmdir .. "\\" .. familyname
	write_tfm(path, familyname, "UNICODE")
	write_tfm(path, familyname .. "sl", "UNICODE", 0.167)
end

generate_tfm("")
generate_tfm("song")
generate_tfm("fs")
generate_tfm("hei")
generate_tfm("kai")
generate_tfm("li")
generate_tfm("you")
