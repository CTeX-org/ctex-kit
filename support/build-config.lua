-- Common settings for ctex-kit development repo, used by l3build script

supportdir    = supportdir    or "../support"
gitverfiles   = gitverfiles   or unpackfiles
unpackexe     = unpackexe     or "luatex"
typesetexe    = typesetexe    or "xelatex"
makeindexexe  = makeindexexe  or "zhmakeindex"
makeindexopts = makeindexopts or "-q"
checkopts     = checkopts     or "-halt-on-error"
typesetopts   = typesetopts   or "-halt-on-error"
binaryfiles   = binaryfiles   or {"*.pdf", "*.zip", "*.luc", "*.tec", "*.tfm", "*.tar.bz2"}

kpse.set_program_name("kpsewhich")
local lookup = kpse.lookup

local md5sum = require("md5").sum
function file_md5 (file)
  local f = io.open(file, "rb")
  if f then
    local data = f:read("*all")
    f:close()
    return data and md5sum(data)
  end
end

typesetruns = typesetruns or 5
typeset = function (file,dir,exe)
  local dir = dir or "."
  local name = jobname(file)
  local path_name = dir .. "/" .. name
  local aux, bbl = path_name .. ".aux", path_name .. ".bbl"
  local glo, idx, hd = path_name .. ".glo", path_name .. ".idx", path_name .. ".hd"
  local aux_md5, bbl_md5, glo_md5, idx_md5, hd_md5
  local prev_aux_md5, prev_bbl_md5, prev_glo_md5, prev_idx_md5, prev_hd_md5
  local errorlevel
  local cnt = 0
  local typeset_flag = true
  while typeset_flag and cnt < typesetruns do
    cnt = cnt + 1
    errorlevel = tex(file,dir,exe)
    if errorlevel ~= 0 then return errorlevel end
    errorlevel = biber(name,dir)
        + bibtex(name,dir)
        + makeindex(name,dir,".glo",".gls",".glg",glossarystyle)
        + makeindex(name,dir,".idx",".ind",".ilg",indexstyle)
    if errorlevel ~= 0 then return errorlevel end
    prev_aux_md5, prev_bbl_md5 = aux_md5, bbl_md5
    prev_glo_md5, prev_idx_md5, prev_hd_md5 = glo_md5, idx_md5, hd_md5
    aux_md5, bbl_md5 = file_md5(aux), file_md5(bbl)
    glo_md5, idx_md5, hd_md5 = file_md5(glo), file_md5(idx), file_md5(hd)
    typeset_flag = aux_md5 ~= prev_aux_md5 or bbl_md5 ~= prev_bbl_md5
                                           or glo_md5 ~= prev_glo_md5
                                           or idx_md5 ~= prev_idx_md5
                                           or hd_md5 ~= prev_hd_md5
  end
  return 0
end


shellescape = os.type == "windows"
  and function (s) return s end
  or  function (s)
        s = s:gsub([[\]], [[\\]])
        s = s:gsub([[%$]], [[\$]])
        return s
      end

git_id_info = { }

function extract_git_version()
  mkdir(supportdir)
  for _,i in ipairs(gitverfiles) do
    for _,j in ipairs({currentdir,supportdir}) do
      for _,k in ipairs(filelist(j, i)) do
        local idfile = normalize_path(supportdir .. "/" .. jobname(k) .. ".id")
        local file = normalize_path(j .. "/" .. k)
        local cmdline = shellescape([[git log -1 --pretty=format:"$Id: ]]
                                        .. k .. [[ %h %ai %an <%ae> $" ]] .. file)
        local  f = assert(io.popen(cmdline, "r"))
        local id = f:read("*all")
        f:close()
        git_id_info[k] = id
        f = assert(io.open(idfile, "wb"))
        f:write(id, "\n")
        f:close()
      end
    end
  end
end

function expand_git_version()
  local sourcedir = tdsdir .. "/source/" .. moduledir
  local texdir    = tdsdir .. "/tex/"    .. moduledir
  for _,i in ipairs(gitverfiles) do
    for _,j in ipairs({sourcedir,texdir}) do
      for _,k in ipairs(filelist(j, i)) do
        replace_git_id(j, k)
      end
    end
  end
end

function replace_git_id (path, file)
  local f = assert(io.open(path .. "/" .. file, "rb"))
  local s = f:read("*all")
  f:close()
  local id = assert(git_id_info[file])
  local s, n = s:gsub([[(\GetIdInfo)%b$$]], "%1" .. id)
  if n > 0 then
    f = assert(io.open(path .. "/" .. file, "wb"))
    f:write(s)
    f:close()
    cp(file, path, ctandir .. "/" .. ctanpkg)
  end
end

-- 共享 update_tag: 回写 .dtx 里的包版本号.
--
-- 位置说明 (名字容易误读): `\ProvidesExplPackage{\ExplFileName}` 之后那行
-- `{\ExplFileDate}{3.10.5}{\ExplFileDescription}` 里, `\ExplFileDate` 是
-- **占位宏**, 由 `\GetIdInfo$Id: ...$` 从 git stamp 取到日期; 大括号里的
-- `3.10.5` 才是版本号, 也是本函数唯一要改的东西. 日期无需 (也不应) 在这里写,
-- 它随 replace_git_id 打包时填入的 commit 日期自动跟进.
--
-- 另外还顺带兼容 `[YYYY/MM/DD v<版本>]` 这种旧式行 (部分包的注释头里有).
--
-- 由 CJKpunct / jiazhu / xCJK2uni / xeCJK / xpinyin / zhmetrics / zhnumber 共用
-- (ctex 与 zhlineskip 在各自 build.lua 里覆写, 走 `$Id:$` stamp 那套).
--
-- 版本事实源的两种模式:
--
--   1. build.lua 设了 `version` (xeCJK, #1041 起): 以它为准, 忽略 CLI 传入的
--      tagname. 这样 `l3build tag` 无参可跑, PR 门禁才能用
--      「l3build tag 后 git diff 必须为零」来拦 version 与 .dtx 失同步.
--   2. 未设 `version` (其余六包): 保持原行为, 用 CLI 的 `l3build tag <ver>`.
--      这些包的 tagname 为 nil 时直接返回原文, 不再像以前那样
--      `nil .. ""` 抛 "attempt to concatenate a nil value".
--
-- 幂等性: 目标版本与文件里已有的一致时原样返回, 使门禁的 diff 为零. 这一步是
-- PR 门禁能成立的前提 -- 若每次 tag 都无条件重写, `l3build tag` 后的 diff 永
-- 不为零, check-tag.yml 就会恒失败.
function update_tag(file, content, tagname, tagdate)
  if not file:match("%.dtx$") then return content end

  -- build.lua 的 version 优先; 它不存在时才用 CLI 参数.
  --
  -- 必须判类型: l3build 自己在全局定义了 `function version()` 供 `--version`
  -- 用 (l3build-help.lua:32), 所以未设 version 的包里这个名字是**函数**而非
  -- nil. 直接 `version or tagname` 会取到那个函数, 后面拼接时报
  -- "attempt to index a function value".
  local target = (type(version) == "string") and version or tagname
  if type(target) ~= "string" then
    -- 未设 version 的包必须用 `l3build tag <版本>`; 漏掉参数时 tagname 为 nil.
    -- 改造前这里会以 `attempt to concatenate a nil value` 崩溃 -- 难读, 但至少可见.
    -- 若改成静默返回, `l3build tag` 会打印 Tagging、退出 0、什么也不改, 使用者以为
    -- 成功了, 比崩溃更危险. 按本仓「参数被忽略时要显式告警」的规则给出可操作提示.
    print(("[build-config] %s: 未指定版本号, 未作任何修改. 本包的 build.lua 没有 "
      .. "`version` 字段, 请用 `l3build tag <版本>`; 或给 build.lua 加 version "
      .. "字段后跑 `l3build tag` (不带参数).")
      :format(file))
    return content
  end
  -- zhlineskip 风格的 "v1.0h" 前缀在本路径不适用, 但容错剥掉以免写出 "vv1.0".
  target = target:gsub("^v", "")
  -- 空串能绕过上面的 type 守卫 (`""` 是 string), 若放过去会写出
  -- `{\ExplFileDate}{}` 并破坏幂等. release 闸能兜住, 但没必要先写坏再靠下游拦.
  if target == "" then
    print(("[build-config] %s: 版本号为空, 未作任何修改."):format(file))
    return content
  end

  -- 设了 version 的包里, CLI 传入的 tagname 会被忽略 (version 才是事实源).
  -- 静默忽略会让 `l3build tag 3.10.6` 看起来成功却什么也没改, 所以显式告警.
  --
  -- 两点说明:
  --   * 路径用当前目录名而非 `module`: xeCJK 的 module 是小写 "xecjk", 目录却是
  --     `xeCJK/`, 用 module 会打印出不存在的 `xecjk/build.lua`.
  --     取目录名用 `lfs.currentdir()` 而非 `os.getenv("PWD")`: 后者是可被污染的
  --     环境变量 (实测 `PWD=/somewhere/else l3build tag 3.10.6` 会打印 `else/build.lua`,
  --     恰恰又是个不存在的路径), 且 Windows 上本就没有 PWD. `lfs` 在 texlua 下是
  --     预置全局表, l3build 自身也用 (l3build-file-functions.lua:32).
  --   * 只告警不中止: update_tag 没有向 l3build 报错的通道 (返回值是新内容, 不是
  --     errorlevel), 而 `error()` 会让 `l3build tag` 以 Lua 栈回溯收场, 对手滑传参
  --     的人更难读. 因此这里只提示; 版本一致性由 check-tag.yml 与 release.yml 两道
  --     CI 闸把关, 不依赖本条消息被人看见.
  if type(version) == "string" and type(tagname) == "string" then
    local cli = tagname:gsub("^v", "")
    if cli ~= target then
      local here = (lfs.currentdir() or ""):match("([^/\\]+)[/\\]?$") or (module or "?")
      print(("[build-config] 忽略命令行版本 %s: %s/build.lua 的 version = %s 才是"
        .. "事实源. 要发新版请改 build.lua 再跑 `l3build tag` (不带参数).")
        :format(tagname, here, target))
    end
  end

  -- 本函数写两处, **幂等守卫的观察范围必须覆盖全部写入范围**: 早期版本只看
  -- `{\ExplFileDate}` 就提前 return, 于是一个 .dtx 同时有两种写法 (xpinyin.dtx
  -- 就是) 且只有后者失同步时, 该行再也不会被修复.
  local date = (tagdate or os.date("%Y-%m-%d")):gsub("%-", "/")
  local new_content = content:gsub("({\\ExplFileDate})%b{}", "%1{" .. target .. "}")

  -- `[<日期> v<版本>]` 行: **只在版本号需要改时才连日期一起重写; 版本号已对则整段
  -- 原样保留, 包括陈旧的日期.**
  --
  -- 这是一个有意的取舍, 不是遗漏 -- 代价与收益都实测过:
  --   * 代价: 「版本对、日期陈旧」这一种状态不再被自动修复. 改造前的旧代码会把它
  --     刷成今天 (zhmetrics/zhmCJK.dtx 是唯一能单独触发该格的文件: 它有 `[...]`
  --     行却没有 `{\ExplFileDate}`).
  --   * 收益: 旧代码在**已同步**的 zhmetrics 上也会把日期刷成今天 -- 每次
  --     `l3build tag` 都产生 diff. 若保留那个行为, 一旦 zhmetrics 接入 PR 门禁,
  --     「tag 后 diff 必须为零」将永远无法满足.
  -- 版本号是发版事实源、日期只是附带信息, 因此优先保证幂等. 需要更新日期时手改,
  -- 或改 version 触发整段重写.
  -- 版本号用 `[^%]%s]+` 而非 `%S+`: 后者会把紧跟其后的 `]` 一起吃掉, 于是
  -- `[2022/07/14 v3.1]` 回写后丢失右括号; 更糟的是版本号已相同时捕获到的是
  -- "3.1]", `v == target` 守卫失效而落进重写分支, 同时破坏内容与幂等性.
  -- 现网两处 `[...]` 行的版本号后都跟着描述文字, 碰不到; 但本函数把这个模式从
  -- "替换的一部分" 提升成了 "幂等守卫的判据", 语义责任更重, 故一并收紧.
  new_content = new_content:gsub("(%[)(%d%d%d%d/%d%d/%d%d) v([^%]%s]+)",
    function (lb, d, v)
      if v == target then return lb .. d .. " v" .. v end
      return lb .. date .. " v" .. target
    end)

  -- 直接返回即可: l3build 的 update_file_tag 会自己按值比较 (l3build-tagging.lua:52
  -- `if content == updated_content then return 0`), 内容相同时根本不落盘. 这里不需
  -- 要再写一次 `if new_content == content` -- 那是无可观察效果的死代码.
  return new_content
end

null_function = function() return 0 end

local insert = table.insert
local os_remove = os.remove

function saveall(names)
  local lvts = names and { } or filelist(testfiledir, "*" .. lvtext)
  if names then
    local uniq = { }
    local glob = "*%s*" .. lvtext
    for _,i in ipairs(names) do
      for _,j in ipairs(filelist(testfiledir, glob:format(i))) do
        if not uniq[j] then
          uniq[j] = true
          insert(lvts, j)
        end
      end
    end
  end
  if next(lvts) then
    checkinit()
    checkinit = null_function
    local stdfile  = testfiledir .. "/%s"    .. tlgext
    local extfile  = testfiledir .. "/%s.%s" .. tlgext
    local opt_engine = options.engine or checkengines
    options.engine = opt_engine
    for _, lvt in ipairs(lvts) do
      local name = lvt:gsub("%" .. lvtext .."$", "")
      save( { name } )
      local stdtlg = file_md5(stdfile:format(name))
      for _, tex in ipairs(opt_engine) do
        if tex ~= stdengine then
          local file = extfile:format(name, tex)
          if file_md5(file) == stdtlg then
            os_remove(file)
          end
        end
      end
    end
  end
end

target_list.saveall = { desc = "Saves all test validation log", func = saveall }

doc_prehook  = doc_prehook  or null_function
doc_posthook = doc_posthook or null_function
unhooked_doc = doc
doc = function (...)
  doc_prehook()
  local retval = unhooked_doc(...)
  doc_posthook()
  return retval
end
target_list.doc.func = doc

unpack_prehook  = unpack_prehook  or null_function
unpack_posthook = unpack_posthook or null_function
unhooked_bundleunpack = bundleunpack
bundleunpack = function (...)
  extract_git_version()
  unpack_prehook()
  local retval = unhooked_bundleunpack(...)
  is_unpacked = true
  unpack_posthook()
  return retval
end
target_list.bundleunpack.func = bundleunpack

install_files_prehook  = install_files_prehook  or null_function
install_files_posthook = install_files_posthook or null_function
unhooked_install_files = install_files
install_files = function (...)
  install_files_bool = true
  install_files_prehook()
  local retval = unhooked_install_files(...)
  install_files_posthook()
  return retval
end

copyctan_prehook  = copyctan_prehook  or null_function
copyctan_posthook = copyctan_posthook or null_function
unhooked_copyctan = copyctan
copyctan = function (...)
  copyctan_prehook()
  local retval = unhooked_copyctan(...)
  expand_git_version()
  copyctan_posthook()
  return retval
end

-- ── CTAN upload 支持 ──────────────────────────────────────────────────────
-- 从 .dtx 读取版本号. 兼容两种风格 (l3build 项目里都有):
--   (a) `{\ExplFileDate}{<ver>}{\ExplFileDescription}` — xeCJK / ctex 为
--       代表的 expl3-only 风格, 版本号显式写在大括号里 (与本文件 update_tag
--       写入端对称).
--   (b) `\GetIdInfo $Id: <file> v<ver> <date> <author>$` — zhlineskip 等
--       传统 docstrip 风格, 版本号在 SVN keyword 串里 (允许字母后缀,
--       如 v1.0f).
-- 失败返回 nil — 调用方可 fallback.
function read_dtx_version(dtx_path)
  local f = io.open(dtx_path, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  local v = content:match("{\\ExplFileDate}{([%d%.]+)}{\\ExplFileDescription}")
  if v then return v end
  return content:match("\\GetIdInfo%s+%$Id:%s+%S+%s+v?([%w%.]+)%s")
end

-- env 读取小工具: GH Actions `env: X: ${{ inputs.x }}` 在 input 留空时
-- 会注入空串 "", 而 `os.getenv("X") or fallback` 把空串当 truthy, 不会
-- 走 fallback. 这里把 nil 和 "" 一并视为未设置, 让 uploadconfig 的
-- `opts.note or ctex_kit_env_or_nil("CTAN_NOTE")` 在空 input 时跳过.
function ctex_kit_env_or_nil(name)
  local v = os.getenv(name)
  if v == nil or v == "" then return nil end
  return v
end

-- 构造 l3build uploadconfig 表. 仓库公共字段固定写在这里, 各包传 opts 覆写
-- pkg / version / author / summary / description / ctanPath 等差异字段.
--
-- 注意: uploader / email / note 留空 (从环境变量读), 由 release-ctan-upload.yml
-- workflow 用 `CTAN_UPLOADER=... CTAN_EMAIL=... CTAN_NOTE=... l3build upload`
-- 注入, 避免把任何个人 email / 临时备注落到 git 里. l3build CLI 只支持
-- --email 覆盖, 不支持 --uploader / --note, 所以走 env 是最通用的办法
-- (本地 / CI 同一套).
function ctex_kit_uploadconfig(opts)
  return {
    pkg               = opts.pkg,
    version           = opts.version,
    author            = opts.author,
    uploader          = opts.uploader     or os.getenv("CTAN_UPLOADER"),
    email             = opts.email        or os.getenv("CTAN_EMAIL"),
    -- CTAN reviewer 内部备注 (≤4096 字符). l3build CLI 不暴露 note 参数,
    -- 仅认 uploadconfig.note / note_file. 走 env 与 uploader/email 一致,
    -- 避免把临时备注写进 build.lua. release-ctan-upload.yml 用 workflow
    -- input 注入 CTAN_NOTE; 本地跑 l3build upload 也是同一套.
    -- CTAN_NOTE 留空 (workflow input 默认值) 时 GH Actions 会注入空串,
    -- 需显式过滤为 nil — 否则 l3build 会把空 note 字段提交给 CTAN.
    note              = opts.note         or ctex_kit_env_or_nil("CTAN_NOTE"),
    license           = opts.license       or "lppl1.3c",
    summary           = opts.summary,
    description       = opts.description,
    topic             = opts.topic         or { "chinese" },
    ctanPath          = opts.ctanPath,
    -- home 字段刻意不设默认值: 默认 home 会与 repository 同为
    -- https://github.com/CTeX-org/ctex-kit, CTAN 对同一包内重复 URL 会
    -- 自动去重并在每次上传回执里提示 "I omitted the identical URL for
    -- 'Home'. (Mind that we wish to use each URL only once.)". 留空 ⟹
    -- l3build ctan_field 跳过 home, CTAN 上 source repository 链接已涵盖
    -- 同一 URL 的导航需求 (见 #914).
    home              = opts.home,
    bugtracker        = opts.bugtracker
                      or "https://github.com/CTeX-org/ctex-kit/issues",
    support           = opts.support
                      or "https://github.com/CTeX-org/ctex-kit/issues",
    repository        = opts.repository
                      or "https://github.com/CTeX-org/ctex-kit",
    development       = opts.development
                      or "https://github.com/CTeX-org",
    announcement_file = opts.announcement_file or "announcement.md",
    update            = (opts.update ~= nil) and opts.update or true,
  }
end
