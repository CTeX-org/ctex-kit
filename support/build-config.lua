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

function update_tag(file, content, tagname, tagdate)
  local content, date = content, tagdate:gsub("%-", "/")
  if file:match("%.dtx$") then
    content = content:gsub("({\\ExplFileDate})%b{}", "%1{" .. tagname .."}")
    content = content:gsub("(%[)%d%d%d%d/%d%d/%d%d v%S+", "%1" .. date .. " v" .. tagname)
  end
  return content
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
-- 从 .dtx 读取版本号 (匹配 `{\ExplFileDate}{<ver>}{\ExplFileDescription}` 形式,
-- 与本文件 update_tag 写入端对称). 失败返回 nil — 调用方可 fallback.
function read_dtx_version(dtx_path)
  local f = io.open(dtx_path, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  -- e.g. `%<!driver>  {\ExplFileDate}{3.10.0}{\ExplFileDescription}`
  return content:match("{\\ExplFileDate}{([%d%.]+)}{\\ExplFileDescription}")
end

-- 构造 l3build uploadconfig 表. 仓库公共字段固定写在这里, 各包传 opts 覆写
-- pkg / version / author / summary / description / ctanPath 等差异字段.
--
-- 注意: uploader / email 留空 (从环境变量读), 由 release-ctan-upload.yml
-- workflow 用 `CTAN_UPLOADER=... CTAN_EMAIL=... l3build upload` 注入, 避免
-- 把任何个人 email 落到 git 里. l3build CLI 只支持 --email 覆盖, 不支持
-- --uploader, 所以走 env 是最通用的办法 (本地 / CI 同一套).
function ctex_kit_uploadconfig(opts)
  return {
    pkg               = opts.pkg,
    version           = opts.version,
    author            = opts.author,
    uploader          = opts.uploader     or os.getenv("CTAN_UPLOADER"),
    email             = opts.email        or os.getenv("CTAN_EMAIL"),
    license           = opts.license       or "lppl1.3c",
    summary           = opts.summary,
    description       = opts.description,
    topic             = opts.topic         or { "chinese" },
    ctanPath          = opts.ctanPath,
    home              = opts.home          or "https://github.com/CTeX-org/ctex-kit",
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
