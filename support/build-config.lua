-- Common settings for ctex-kit development repo, used by l3build script

supportdir    = supportdir    or "../support"
unpackexe     = unpackexe     or "luatex"
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

dtxchecksum = require(lookup("dtxchecksum.lua", {path=supportdir})).checksum
function checksum()
  if not is_unpacked then unpack() end
  unpack = null_function
  for _,i in ipairs(typesetsuppfiles) do
    cp(i, supportdir, localdir)
  end
  for _,glob in ipairs(typesetfiles) do
    for _,f in ipairs(filelist(".", glob)) do
      if f:sub(-4) == ".dtx" then
        dtxchecksum(f, localdir)
      end
    end
  end
end

target_list = target_list or { }

target_list.checksum = { desc = "Adjust \\CheckSum{...}", func = checksum }

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

function saveall(names)
  local names, opt_engine = names, options.engine
  local t, engines = { }, { }
  if opt_engine then
    for _,i in ipairs(opt_engine) do engines[i] = true end
  end
  local lvts = names and { }
  if names then
    local uniq = { }
    local glob = "*%s*.tlg"
    for _,i in ipairs(names) do
      for _,j in ipairs(filelist(testfiledir, glob:format(i))) do
        if not uniq[j] then
          uniq[j] = true
          insert(lvts, j)
        end
      end
    end
  end
  for _,file in ipairs(lvts or filelist(testfiledir, "*.tlg")) do
    local base = jobname(file)
    local lvt, tex = base:match([[^(.+)%.(%w+)$]])
    local lvt = lvt or base
    local tex = tex or stdengine
    if not t[tex] then t[tex] = { } end
    insert(t[tex], lvt)
  end
  if next(t) then
    checkinit()
    checkinit = null_function
    for _, tex in ipairs(checkengines) do
      local lvts = t[tex]
      if lvts and (not next(engines) or engines[tex]) then
        options.engine = { tex }
        save(lvts)
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
  checksum()
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

