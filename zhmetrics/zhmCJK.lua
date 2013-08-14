-- Copyright (C) 2012 by Leo Liu <leoliu.pku@gmail.com>
-----------------------------------------------------------------------------
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3 or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
--
-- This work has the LPPL maintenance status `maintained'.
--
-- The Current Maintainer of this work is Leo Liu.
--
-- This work consists of the files zhmCJK.dtx,
--                                 zhmCJK.ins,
--                                 zhmCJK.lua,
--           and the derived files zhmCJK.sty,
--                                 zhmCJK.pdf,
--                                 zhmCJK-test.tex,
--                                 README.txt,              (from zhmCJK.dtx)
--                                 zhmCJK.map,
--                                 texfonts.map,
--                                 zhmCJK.tfm,
--                                 fallback/zhm*/zhm**.tfm. (from zhmCJK.lua)
--
-----------------------------------------------------------------------------
-- This lua script is used to generate zhm*.tfm and zhmCJK.map.
--
-- Usage:
--
--    texlua zhmCJK.lua map
--
-- or (for MiKTeX only)
--
--    texlua zhmCJK.lua nomap
--

------------------------
-- OS dependent settings
------------------------

if os.type == "unix" then
    path_slash = "/"
else
    path_slash = "\\"
end

---------------
-- Generate TFM
---------------

pl_template = {
    char = [[
(CHARACTER D %d
    (CHARWD R 1.0)
    (CHARHT R 0.8)
    (CHARDP R 0.1)
    )
]],
    header = [[
(FAMILY %s)
(CODINGSCHEME CJK-UNICODE)
(DESIGNSIZE R 10.0)
(HEADER D 18 H 43726561)
(HEADER D 19 H 74656420)
(HEADER D 20 H 62792060)
(HEADER D 21 H 7A686D43)
(HEADER D 22 H 4A4B2E6C)
(HEADER D 23 H 7561272E)
(HEADER D 24 H 20436F70)
(HEADER D 25 H 79726967)
(HEADER D 26 H 68742028)
(HEADER D 27 H 43292032)
(HEADER D 28 H 30313220)
(HEADER D 29 H 6279204C)
(HEADER D 30 H 656F204C)
(HEADER D 31 H 6975203C)
(HEADER D 32 H 6C656F6C)
(HEADER D 33 H 69752E70)
(HEADER D 34 H 6B754067)
(HEADER D 35 H 6D61696C)
(HEADER D 36 H 2E636F6D)
(HEADER D 37 H 3E0D0A00)
(CHECKSUM O 0)
(FONTDIMEN
    (SLANT R %f)
    (SPACE R 0.5)
    (STRETCH R 0.3)
    (SHRINK R 0.1)
    (XHEIGHT R 0.4)
    (QUAD R 1.0)
    )
]],
--   charset = (defined below)
}

function pl_charset()
    local charset = {}
    for cid = 0, 0xff do
        charset[#charset + 1] = string.format(pl_template.char, cid)
    end
    return table.concat(charset)
end

pl_template.charset = pl_charset()

function write_tfm(path, name, slant)
    local fullname = path .. path_slash .. name
    local s_pl = string.format(pl_template.header, string.upper(name), slant)
        .. pl_template.charset
    local f_pl = io.open(fullname .. ".pl", "w")
    f_pl:write(s_pl)
    f_pl:close()
    os.execute([[pltotf "]] .. fullname .. [[.pl" "]] .. fullname .. [[.tfm"]])
    os.remove(fullname .. ".pl")
end

---------------------------------------------
-- Main functions to generate necessary files
---------------------------------------------

-- For TeX Live and other TeX distributions where texfonts.map is supported,
-- we generate texfonts.map, zhmCJK.map, and zhmCJK.tfm.
function generate_with_fontmap()
    local f_map = io.open("zhmCJK.map", "w")
    for fam = 1, 32 do
        for sid = 0, 0xff do
            f_map:write(string.format("zhmCJK.tfm zhm%d%02x.tfm\n",
                fam, sid))
        end
    end
	f_map:write("\n")
    f_map:close()

    f_map = io.open("texfonts.map", "w")
    f_map:write("include zhmCJK.map\n\n")
    f_map:close()

    write_tfm(".", "zhmCJK", 0.0)
end

-- For MiKTeX and other TeX distributions where texfonts.map is not supported,
-- we generate a lot of zhmXYY.tfm, where X from 1 to 32, Y from 0x00 to 0xff.
function generate_without_fontmap()
    lfs.mkdir("fallback")
    for fam = 1, 32 do
        local path = string.format("fallback" .. path_slash .. "zhm%d", fam)
        lfs.mkdir(path)
        print(path)
        for sid = 0, 0xff do
            local name = string.format("zhm%d%02x", fam, sid)
            write_tfm(path, name, 0.0)
        end
    end
end

-------------------------
-- Console User Interface
-------------------------

help_info = [[
Usage:

    texlua ]].. arg[0] .. [[ map|nomap

    map:    Generate a public TFM shared by all CJK fonts with mapping files.
            It is suggested for TeX Live and other web2c distributions.

    nomap:  Generate all TFM files for CJK fonts into "fallback" directory.
            MiKTeX needs this since it does not support TFM mappings.
]]

if #arg ~= 1 then 
    print(help_info)
else
    if arg[1] == "map" then
        generate_with_fontmap()
    elseif arg[1] == "nomap" then
        generate_without_fontmap()
    else
        print("! Unknown option " .. arg[1])
        print(help_info)
    end
end

-- end of file zhmCJK.lua --
--
-----------------------------------------------------------------------------
--
-- The code is inspired by zhtfm.lua of zhmetrics bundle.
--
-- The zhmetrics bundle is distributed under LPPL 1.3 or later. The original
-- authors of zhtfm.lua are:
--
--        Lingyun Wu    <wulingyun@gmail.com>
--        zwhuang       <zwhuang@gmail.com>
--
-- For more information of zhmetrics, see the ctex-kit project:
--
--        http://code.google.com/p/ctex-kit/
--

