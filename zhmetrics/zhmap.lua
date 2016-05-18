-- use tfm font alias mechanism to reduce the number of tfm files;
-- this script generates tfm font map files for Chinese fonts;
--
-- font alias can only be stored in `texfonts.map' !!!
-- and `texfonts.map' is enough to make latex/pdflatex/dvipdf(m(x))/dvips
-- all work, so, zhgbkfonts.map and zhunifonts.map will not be needed;
--
-- modified by <zwhuang@gmail.com>
-- 2009-11-15 [15:29]

-- global settings
settings = {
    mapdir = [[fonts\map\zhmetrics]],
    cjknamelist = {"", "song", "fs", "hei", "kai", "li", "you"},
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

-- create map lines for one font family;
function map_lines (familyname_v, encoding_v)
    local familyname, encoding, sid, str_sid, max_sid
    familyname = string.lower(familyname_v)
    encoding = string.upper(encoding_v)
    if encoding == "UGBK" then
        max_sid = 94
        format = "%02d"
    elseif encoding == "UNICODE" then
        max_sid = 255
        format = "%02x"
    else
        print("Error: Unknown encoding!")
        exit(1)
    end
    local mapset = {}
    -- map lines for normal fonts;
    for sid = 0, max_sid do
        str_sid = string.format(format, sid)
        mapset[#mapset + 1] = ("zhmetrics.tfm " .. familyname .. str_sid .. ".tfm\n")
    end
    -- map lines for slant fonts;
    for sid = 0, max_sid do
        str_sid = string.format(format, sid)
        mapset[#mapset + 1] = ("zhmetrics.tfm " .. familyname .. "sl" .. str_sid .. ".tfm\n")
    end
    return table.concat(mapset)
end

-- wrap map lines to a list;
function map_list (familynamelist, encoding)
    local mapsets = {}
    for i = 1, #familynamelist do
        mapsets[#mapsets + 1] = map_lines(familynamelist[i], encoding)
        mapsets[#mapsets + 1] = "\n"
    end
    return table.concat(mapsets)
end

function generate_map (cjknamelist)
    local cjkname, familynamelist, path
    local texfontsmap = ""
    path = settings.mapdir
    familynamelist = {}
    for i = 1, #cjknamelist do
        familynamelist[#familynamelist + 1] = "gbk" .. string.lower(cjknamelist[i])
    end
    texfontsmap = texfontsmap .. map_list(familynamelist, "UGBK")
    familynamelist = {}
    for i = 1, #cjknamelist do
        if (cjknamelist[i] == "") then
            familynamelist[#familynamelist + 1] = "cyberb"
        else
            familynamelist[#familynamelist + 1] = "uni" .. string.lower(cjknamelist[i])
        end
    end
    texfontsmap = texfontsmap .. map_list(familynamelist, "UNICODE")
    -- alias simsun.ttf and simsun.ttc mutually;
    texfontsmap = texfontsmap .. "simsun.ttf simsun.ttc\n"
    texfontsmap = texfontsmap .. "simsun.ttc simsun.ttf\n"
    -- generate tfm font alias map file `texfonts.map';
    mkdir(path)
    local filename = path .. "\\" .. "texfonts.map"
    local f = io.open(filename, "w")
    print(filename)
    f:write(texfontsmap)
    f:close()
end

-- settings.cjknamelist = {"", "song"}

generate_map(settings.cjknamelist)
