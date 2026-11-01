-- Per-step ownership facts only. Never claims the entire route is accessible.
local P={}
function P.evaluate(guidance,snapshot,readName)
 local result,seen={},{}
 for _,note in ipairs(guidance or{})do
  for _,check in ipairs(note.checks or{})do
   assert(check.category=='weapon' or check.category=='phantom_edge','only persistent weapon ownership is supported')
   local key=check.category..'/'..check.id:lower()
   if not seen[key]then
    seen[key]=true
    local state='unknown'
    local owned=snapshot.owned and snapshot.owned[check.category]
    if snapshot.ready[check.category] and owned and readName(check.category,check.id)==check.title then
     local value=owned[check.id:lower()]
     assert(value==nil or value==true,'ownership map must contain present keys only')
     state=value and'owned'or'missing'
    end
    result[#result+1]={category=check.category,id=check.id,title=check.title,state=state}
   end
  end
 end
 return result
end
return P
