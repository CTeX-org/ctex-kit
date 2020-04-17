#!/usr/bin/env texlua

local ctex_kit = {
  "CJKpunct"        ,
  "ctex"            ,
  "xCJK2uni"        ,
  "xeCJK"           ,
  "xpinyin"         ,
  "zhmetrics"       ,
  "zhmetrics-uptex" ,
  "zhnumber"        ,
  "zhspacing"       ,
}

local ctan = #arg > 0 and arg or ctex_kit
 
for _, pkg in ipairs(ctan) do
  local currdir = lfs.currentdir()
  lfs.chdir(pkg)
  os.execute("l3build ctan")
  lfs.chdir(currdir)
end
