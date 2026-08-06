
module = "zhnumber"

-- 发版事实源. 与 zhnumber.dtx 里紧跟 `{\ExplFileDate}` 之后那个参数必须一致
-- (即 `{\ExplFileDate}{3.3}` 中的 `3.3`; \ExplFileDate 本身是日期槽位,
--  \ProvidesExplPackage 的参数顺序是 文件名／日期／版本／说明):
--   * 本地发版流程: 改这里 -> `l3build tag` 回写 .dtx -> commit;
--   * PR 校验 check-tag.yml 跑 `l3build tag` 后要求 git diff 为零;
--   * release.yml 打 tag 时校验 git tag / version / .dtx 三方一致.
--
-- 为什么必须设这个字段 (而不是继续用 `l3build tag <版本>`):
-- 不设时, 不带参数的 `l3build tag` 会打印「未指定版本号, 未作任何修改」并
-- **以 0 退出** (见 support/build-config.lua 的共享 update_tag). 于是仿 xpinyin
-- 写的 check-tag job 会恒绿 —— 跑了 tag、diff 自然为零、什么也没校验.
-- 实测确认: 加本字段前 `l3build tag` 不改任何文件, 加后回写并保持幂等.
version = "3.3"

packtdszip = true

sourcefiles      = {"zhnumber.dtx"}
unpackfiles      = {"zhnumber.dtx"}
installfiles     = {"*.sty", "*.cfg", "*.ins"}
unpacksuppfiles  = {"zhnumber.id", "ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-index.lua"}
typesetsuppfiles = {"ctxdoc.cls"}

testfiledir  = "./testfiles"
stdengine    = "xetex"
checkengines = {"pdftex", "xetex", "luatex"}

tdslocations = {
  "source/latex/zhnumber/*.ins",
}

dofile("../support/build-config.lua")
