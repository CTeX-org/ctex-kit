zhpunc = {}

local has_attribute      = node.has_attribute
local glyph = node.id('glyph')
local hlist = node.id('hlist') 
local number_to_kind = scripts.number_to_kind
local prestat = attributes.numbers['prestat']

local insert_node_after = node.insert_after
local insert_node_before = node.insert_before
local make_glue_node = nodes.glue
local fontdata = fonts.ids

local zhpunc_space  = 0

local function set_parameters(font, data)
   local parameters = fontdata[font].parameters
   local quad = (parameters and parameters.quad or parameters[6]) or 0
   zhpunc_space = (data.zhpunc_space_factor / data.num) * quad
end

local dataset = {
   num = 1,
   zhpunc_space_factor = 0.55,
}

function zhpunc.proc (head, groupcode)
   if groupcode ~= "" then return true end

   local tmpnode = head
   local paralist = {}
   local pcount = 0
   while tmpnode do
      if tmpnode.id == hlist then
	 pcount = pcount + 1
	 paralist[pcount] = tmpnode
      end
      tmpnode = tmpnode.next
   end

   for i, para in ipairs (paralist) do
      if i == pcount then break end
      local lcount = 0
      local inline = para.list
      local last = nil
      local line = {}
      while inline do
	 if inline.id == glyph then
	    lcount = lcount + 1
	    line[lcount] = inline
	    last = inline
	 end
	 inline = inline.next
      end
      if last then
	 local a = has_attribute(last, prestat)
	 local zhchar = number_to_kind[a]
	 if zhchar == "full_width_close" then
	    local font = last.font
	    dataset.num = lcount
	    set_parameters(font,dataset)
	    for j, v in ipairs (line) do
	       insert_node_after(head, v, make_glue_node(zhpunc_space, 0, 0))
	    end
	 end
	 line = nil
      end
   end
   return head
end

return zhpunc
