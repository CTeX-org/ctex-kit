
module = "xcjk2uni"

-- 发版事实源. 与 xCJK2uni.dtx 里紧跟 `{\ExplFileDate}` 之后那个参数必须一致
-- (即 `{\ExplFileDate}{1.0}` 中的 `1.0`; \ExplFileDate 本身是日期槽位,
--  \ProvidesExplPackage 的参数顺序是 文件名／日期／版本／说明).
-- 与 zhnumber 同批接入 (见该包 build.lua 的说明): 不设本字段时不带参数的
-- `l3build tag` 会打印「未指定版本号」并以 0 退出, 使 check-tag job 恒绿.
--
-- 注意本包的 module 是小写 `xcjk2uni` 而目录是 `xCJK2uni/`; 校验里凡是拼路径
-- 的地方都要用目录名而非 module (共享 update_tag 的告警文案踩过同一个坑, 见
-- support/build-config.lua 里关于 lfs.currentdir() 的说明).
version = "1.0"

packtdszip = true

sourcefiles      = {"xCJK2uni.dtx"}
unpackfiles      = {"xCJK2uni.dtx"}
installfiles     = {"*.sty", "xCJK2uni-U*.def", "*.cmap", "*.ins"}
unpacksuppfiles  = {"xCJK2uni.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "source/latex/xcjk2uni/*.ins",
  "tex/latex/xcjk2uni/cmap/*.cmap",
}

dofile("../support/build-config.lua")
