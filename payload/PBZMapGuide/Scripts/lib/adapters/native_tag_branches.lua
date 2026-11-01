-- Copy configuration only. No condition execution and no inferred false-branch inversion.
local Branches={}
function Branches.read(node,deps)
 assert(type(node.ConditionsAnd)=='boolean','invalid native branch combination flag')
 local property
 node:GetClass():ForEachProperty(function(value)
  if value:GetFName():ToString()=='Conditions'then assert(not property,'ambiguous branch conditions');property=value end
 end)
 assert(property and property:GetFullName():match('^ArrayProperty '),'native branch conditions array unavailable')
 local shape=property:GetInner():GetStruct()
 assert(shape:GetFullName():match('/FlowGraph/Struct/TagCondition%.TagCondition$'),'unsupported native tag condition structure')
 local fields={}
 shape:ForEachProperty(function(value)
  local name=value:GetFName():ToString();local base,suffix=name:match('^([%a]+)_%d+_(%x+)$')
  if base and suffix and #suffix==32 and(base=='AllowTags'or base=='DenyTags')then
   assert(not fields[base]and value:GetFullName():match('^StructProperty '),'ambiguous native branch tag field')
   fields[base]=name
  end
 end)
 assert(fields.AllowTags and fields.DenyTags,'native branch tag fields unavailable')
 local values=node.Conditions;assert(#values<=64,'native branch group bound')
 local result={conditions_and=node.ConditionsAnd,groups={}};local containers={}
 values:ForEach(function(_,parameter)
  local value=parameter:get()
  result.groups[#result.groups+1]={allow=deps.tags(value[fields.AllowTags]),deny=deps.tags(value[fields.DenyTags])}
  if deps.query_group then containers[#containers+1]=value[fields.AllowTags]end
 end)
 -- Native predicate calls run after the borrowed array callback, within this read only.
 if deps.query_group then for i,group in ipairs(result.groups)do group.current=deps.query_group(containers[i],group.deny)end end
 return result
end
return Branches
