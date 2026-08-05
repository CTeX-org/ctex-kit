
module = "zhmcjk"

-- 发版事实源. 与 zhmCJK.dtx 的 `[<日期> v<版本> ...]` 行里 `v` 后面那段必须一致
-- (当前是 `[2022/07/09 v0.9d setup CJK fonts dynamically]`). 本包用的是**旧式**
-- 版本写法, 不是 `{\ExplFileDate}{<ver>}` —— 共享 update_tag 两种都会回写.
--
-- 与 zhnumber / xCJK2uni 同批接入 (见那两个包 build.lua 的说明). 本包是三者中
-- 最容易漏掉的一个: 它既有 `zhmetrics-v*` 触发器 (能发版), 又只有旧式写法, 于是
-- 只按 `{\ExplFileDate}` 找版本槽位的对账手段扫不到它 —— 盲审正是这样查出来的.
-- 实测 `l3build tag 9.9.9` 会回写 zhmCJK.dtx 一行, 确认它确实走这套机制.
--
-- 注意 module 是 `zhmcjk`、目录是 `zhmetrics/`、tag 前缀是 `zhmetrics-v*`、
-- 而 CHANGELOG 里的历史条目写的是 `zhmCJK-v0.9d` —— 四个名字互不相同, 凡是拼
-- 路径或匹配 tag 的地方都要按各自的坐标系来, 不能互相套用.
version = "0.9d"

packtdszip = true

gitverfiles  = { }
sourcefiles  = {"zhmCJK.dtx", "zhmCJK.ins", "zhmCJK.lua", "zhmCJK-addmap.pl"}
unpackfiles  = {"zhmCJK.ins"}
installfiles = {"zhmCJK.sty"}
typesetfiles = {"zhmCJK.dtx", "zhmCJK-test.tex"}
unpackexe    = "pdftex"
typesetexe   = "latex"


function docinit_hook()
  cp("zhmCJK-test.tex", unpackdir, typesetdir)
  return 0
end

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = jobname(i)
    run(typesetdir, "dvipdfmx " .. name)
    cp(name .. ".pdf", typesetdir, currentdir)
  end
end

function copyctan_posthook()
  mkdir(supportdir)
  cp("zhmCJK.lua", currentdir, supportdir)
  run(supportdir, "texlua zhmCJK.lua map")
  if not lfs.isfile(supportdir .. "/miktex-tfm.tar.bz2") then
    run(supportdir, "texlua zhmCJK.lua nomap")
    run(supportdir, "tar --remove-files -cjf miktex-tfm.tar.bz2 miktex-tfm")
  end
  local ctandir = ctandir .. "/" .. ctanpkg
  local mapdir = tdsdir .. "/fonts/map/fontname"
  mkdir(mapdir)
  for _, i in ipairs{"texfonts.map.template", "zhmCJK.map"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, mapdir)
  end
  local tfmdir = tdsdir .. "/fonts/tfm/" .. ctanpkg
  mkdir(tfmdir)
  for _, i in ipairs{"zhmCJK.tfm", "miktex-tfm.tar.bz2"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, tfmdir)
  end
end

dofile("../support/build-config.lua")
