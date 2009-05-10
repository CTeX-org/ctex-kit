if not modules then modules = { } end modules ['scrp-ini'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_analyzing  = false  trackers.register("scripts.analyzing",  function(v) trace_analyzing  = v end)
local trace_injections = false  trackers.register("scripts.injections", function(v) trace_injections = v end)

local set_attribute   = node.set_attribute
local has_attribute   = node.has_attribute
local first_character = node.first_character
local traverse_id     = node.traverse_id

local glyph   = node.id('glyph')
local glue    = node.id('glue')
local penalty = node.id('penalty')

local fcs = (fonts.color and fonts.color.set)   or function() end
local fcr = (fonts.color and fonts.color.reset) or function() end

local state   = attributes.private('state')
local preproc = attributes.private('preproc')
local prestat = attributes.private('prestat')

local fontdata = fonts.ids

scripts          = scripts          or { }
scripts.handlers = scripts.handlers or { }

scripts.names    = scripts.names    or { }
scripts.numbers  = scripts.numbers  or { }
scripts.hash     = scripts.hash     or { }

storage.register("scripts/hash", scripts.hash, "scripts.hash")

if not next(scripts.hash) then

    local hash = {
        --
        -- half width opening parenthesis
        -- [0x0028] = "half_width_open",
        -- [0x005B] = "half_width_open",
        -- [0x007B] = "half_width_open",
        [0x2018] = "half_width_open", -- ‘
        [0x201C] = "half_width_open", -- “
        --
        -- full width opening parenthesis
        --
        [0x3008] = "full_width_open", -- 〈   Left book quote
        [0x300A] = "full_width_open", -- 《   Left double book quote
        [0x300C] = "full_width_open", -- 「   left quote
        [0x300E] = "full_width_open", -- 『   left double quote
        [0x3010] = "full_width_open", -- 【   left double book quote
        [0x3014] = "full_width_open", -- 〔   left book quote
        [0x3016] = "full_width_open", --〖   left double book quote
        [0x3018] = "full_width_open", --     left tortoise bracket
        [0x301A] = "full_width_open", --     left square bracket
        [0x301D] = "full_width_open", --     reverse double prime qm
        [0xFF08] = "full_width_open", -- （   left parenthesis
        [0xFF3B] = "full_width_open", -- ［   left square brackets
        [0xFF5B] = "full_width_open", -- ｛   left curve bracket
        [0xFF62] = "full_width_open", --     left corner bracket
        --
        -- half width closing parenthesis
        -- [0x0029] = "half_width_close",
        -- [0x005D] = "half_width_close",
        -- [0x007D] = "half_width_close",
        [0x2019] = "half_width_close", -- ’   right quote, right
        [0x201D] = "half_width_close", -- ”   right double quote
        --
        -- full width closing parenthesis
        --
        [0x3009] = "full_width_close", -- 〉   book quote
        [0x300B] = "full_width_close", -- 》   double book quote
        [0x300D] = "full_width_close", -- 」   right quote, right
        [0x300F] = "full_width_close", -- 』   right double quote
        [0x3011] = "full_width_close", -- 】   right double book quote
        [0x3015] = "full_width_close", -- 〕   right book quote
        [0x3017] = "full_width_close", -- 〗  right double book quote
        [0x3019] = "full_width_close", --     right tortoise bracket
        [0x301B] = "full_width_close", --     right square bracket
        [0x301E] = "full_width_close", --     double prime qm
        [0x301F] = "full_width_close", --     low double prime qm
        [0xFF09] = "full_width_close", -- ）   right parenthesis
        [0xFF3D] = "full_width_close", -- ］   right square brackets
        [0xFF5D] = "full_width_close", -- ｝   right curve brackets
        [0xFF63] = "full_width_close", --     right corner bracket
        --
        -- vertical opening vertical
        --
        -- 0xFE35, 0xFE37, 0xFE39,  0xFE3B,  0xFE3D,  0xFE3F,  0xFE41,  0xFE43,  0xFE47,
        --
        -- vertical closing
        --
        -- 0xFE36, 0xFE38, 0xFE3A,  0xFE3C,  0xFE3E,  0xFE40,  0xFE42,  0xFE44,  0xFE48,
        --
        -- half width opening punctuation
        --
        -- <empty>
        --
        -- full width opening punctuation
        --
        --  0x2236, -- ∶
        --  0xFF0C, -- ，
        --
        -- half width closing punctuation_hw
        --
        [0x0021] = "half_width_close", -- !
        [0x002C] = "half_width_close", -- ,
        [0x002E] = "half_width_close", -- .
        [0x003A] = "half_width_close", -- :
        [0x003B] = "half_width_close", -- ;
        [0x003F] = "half_width_close", -- ?
        [0xFF61] = "half_width_close", -- hw full stop
        --
        -- full width closing punctuation
        [0x3001] = "full_width_close", -- 、
        [0x3002] = "full_width_close", -- 。
        [0xFF01] = "full_width_close", -- ！
        [0xFF0C] = "full_width_close", -- ，
        [0xFF0E] = "full_width_close", -- ．
        [0xFF1A] = "full_width_close", -- ：
        [0xFF1B] = "full_width_close", -- ；
        [0xFF1F] = "full_width_close", -- ？
        --
        -- non starter
        --
        [0x3005] = "non_starter", [0x3041] = "non_starter", [0x3043] = "non_starter", [0x3045] = "non_starter", [0x3047] = "non_starter",
        [0x3049] = "non_starter", [0x3063] = "non_starter", [0x3083] = "non_starter", [0x3085] = "non_starter", [0x3087] = "non_starter",
        [0x308E] = "non_starter", [0x3095] = "non_starter", [0x3096] = "non_starter", [0x309B] = "non_starter", [0x309C] = "non_starter",
        [0x309D] = "non_starter", [0x309E] = "non_starter", [0x30A0] = "non_starter", [0x30A1] = "non_starter", [0x30A3] = "non_starter",
        [0x30A5] = "non_starter", [0x30A7] = "non_starter", [0x30A9] = "non_starter", [0x30C3] = "non_starter", [0x30E3] = "non_starter",
        [0x30E5] = "non_starter", [0x30E7] = "non_starter", [0x30EE] = "non_starter", [0x30F5] = "non_starter", [0x30F6] = "non_starter",
        [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31F0] = "non_starter", [0x31F1] = "non_starter",
        [0x30F2] = "non_starter", [0x30F3] = "non_starter", [0x30F4] = "non_starter", [0x31F5] = "non_starter", [0x31F6] = "non_starter",
        [0x30F7] = "non_starter", [0x30F8] = "non_starter", [0x30F9] = "non_starter", [0x31FA] = "non_starter", [0x31FB] = "non_starter",
        [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31FF] = "non_starter",
        --
        -- hyphenation
        --
        [0x2026] = "hyphen", -- …   ellipsis
        [0x2014] = "hyphen", -- —   hyphen
    }

    for i=0x03040,0x0309F do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x030A0,0x030FF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x031F0,0x031FF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x03400,0x04DFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x04E00,0x09FFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0F900,0x0FAFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0FF00,0x0FFEF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x20000,0x2A6DF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x2F800,0x2FA1F do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0AC00,0x0D7A3 do if not hash[i] then hash[i] = "korean"       end end
    for i=0x01100,0x0115F do if not hash[i] then hash[i] = "jamo_initial" end end
    for i=0x01160,0x011A7 do if not hash[i] then hash[i] = "jamo_medial"  end end
    for i=0x011A8,0x011FF do if not hash[i] then hash[i] = "jamo_final"   end end

    scripts.hash = hash

end

scripts.colors = {  -- todo: just named colors
    korean           = "font:isol",
    chinese          = "font:rest",
    full_width_open  = "font:init",
    full_width_close = "font:fina",
    half_width_open  = "font:init",
    half_width_close = "font:fina",
    hyphen           = "font:medi",
    non_starter      = "font:isol",
    jamo_initial     = "font:init",
    jamo_medial      = "font:medi",
    jamo_final       = "font:fina",

}

scripts.number_to_kind = {
    "korean",
    "chinese",
    "full_width_open",
    "full_width_close",
    "half_width_open",
    "half_width_close",
    "hyphen",
    "non_starter",
    "jamo_initial",
    "jamo_medial",
    "jamo_final",
}

scripts.kind_to_number = {
    korean           =  1,
    chinese          =  2,
    full_width_open  =  3,
    full_width_close =  4,
    half_width_open  =  5,
    half_width_close =  6,
    hyphen           =  7,
    non_starter      =  8,
    jamo_initial     =  9,
    jamo_medial      = 10,
    jamo_final       = 11,
}

local kind_to_number = scripts.kind_to_number
local number_to_kind = scripts.number_to_kind

-- no, this time loading the lua always precedes the definitions
--
-- storage.register("scripts/names",   scripts.names,   "scripts.names")
-- storage.register("scripts/numbers", scripts.numbers, "scripts.numbers")

local handlers = scripts.handlers
local names    = scripts.names
local numbers  = scripts.numbers
local hash     = scripts.hash
local colors   = scripts.colors

-- maybe also process

function scripts.install(handler)
    local name = handler.name
    if not names[name] then
        local n = #numbers + 1
        numbers[n] = name
        names[name] = n
        handlers[n] = handler
    end
    return names[name]
end

function scripts.define(name)
    tex.write(names[name] or attributes.unsetvalue)
end

-- some time i will make a fonts.originals[id]

local function colorize(start,stop)
    for n in traverse_id(glyph,start) do
        local kind = number_to_kind[has_attribute(n,prestat)]
        if kind then
            local ac = colors[kind]
            if ac then
                fcs(n,ac)
            end
        end
        if n == stop then
            break
        end
    end
end

local function traced_process(head,first,last,process,a)
    if start ~= last then
        local f, l = first, last
        logs.report("preprocess","before %s: %s",names[a] or "?",nodes.tosequence(f,l))
        process(head,first,last)
        logs.report("preprocess","after %s: %s", names[a] or "?",nodes.tosequence(f,l))
    end
end

-- eventually we might end up with more extensive parsing
-- todo: pass t[start..stop] == original

function scripts.preprocess(head)
    local start = first_character(head)
    if not start then
        return head, false
    else
        local last_a, normal_process, lastfont, originals = nil, nil, nil, nil
        local done, first, last, ok = false, nil, nil, false
        while start do
            local id = start.id
            if id == glyph then
                local a = has_attribute(start,preproc)
                if a then
                    if a ~= last_a then
                        if first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok, done = false, true
                            end
                            first, last = nil, nil
                        end
                        last_a = a
                        local handler = handlers[a]
                        normal_process = handler.process
                    end
                    if normal_process then
                        local f = start.font
                        if f ~= lastfont then
                            originals = fontdata[f].originals
                            lastfont = f
                        end
                        local c = start.char
                        if originals then c = originals[c] or c end
                        local h = hash[c]
                        if h then
                            set_attribute(start,prestat,kind_to_number[h])
                            if not first then
                                first, last = start, start
                            else
                                last = start
                            end
                        --    if cjk == "chinese" or cjk == "korean" then -- we need to prevent too much ( ) processing
                                ok = true
                        --    end
                        elseif first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok, done = false, true
                            end
                            first, last = nil, nil
                        end
                    end
                elseif first then
                    if ok then
                        if trace_analyzing then
                            colorize(first,last)
                        end
                        if trace_injections then
                            traced_process(head,first,last,normal_process,last_a)
                        else
                            normal_process(head,first,last)
                        end
                        ok, done = false, true
                    end
                    first, last = nil, nil
                end
            elseif id == glue then
                if ok then
                    -- continue
                elseif first then
                    -- no chinese or korean
                    first, last = nil, nil
                end
            elseif first then
                if ok then
                    -- some chinese or korean
                    if trace_analyzing then
                        colorize(first,last)
                    end
                    if trace_injections then
                        traced_process(head,first,last,normal_process,last_a)
                    else
                        normal_process(head,first,last)
                    end
                    first, last, ok, done = nil, nil, false, true
                elseif first then
                    first, last = nil, nil
                end
            end
            start = start.next
        end
        if ok then
            if trace_analyzing then
                colorize(first,last)
            end
            if trace_injections then
                traced_process(head,first,last,normal_process,last_a)
            else
                normal_process(head,first,last)
            end
            done = true
        end
        return head, done
    end
end
