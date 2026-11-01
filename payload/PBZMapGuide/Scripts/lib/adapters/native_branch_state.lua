-- Exact template lookup and native tag predicates only. No CheckConditions or flow execution.
local Branch={}
local function guid(v)return string.format('%08X%08X%08X%08X',v.A%4294967296,v.B%4294967296,v.C%4294967296,v.D%4294967296)end
function Branch.read(path,id,deps)
 local ok,result=pcall(function()
  assert(type(path)=='string'and path:match('^/Game/')and type(id)=='string'and #id==32 and id:match('^%x+$'),'invalid exact branch identity')
  local asset=deps.load(path);assert(asset and asset:IsValid(),'branch template unavailable')
  local nodes=asset.Nodes;assert(#nodes<=512,'native branch node bound');local matches={}
  nodes:ForEach(function(key,value)if guid(key:get())==id:upper()then matches[#matches+1]=value:get()end end)
  assert(#matches==1,'branch identity not unique');local node=matches[1]
  assert(node:IsValid()and guid(node.NodeGuid)==id:upper(),'branch node identity changed')
  assert(node:GetClass():GetFullName()=='BlueprintGeneratedClass /Game/PBZContent/Blueprint/FlowGraph/FlowGraphNode/IsTagBranch.IsTagBranch_C'and node.SignalMode==0,'unsupported active tag branch')
  local queried,allowQueries,tagQueries={},0,0
  local function state(value)return type(value)=='boolean'and(value and'true'or'false')or'unknown'end
  local config=deps.read(node,{tags=deps.tags,query_group=function(container,deny)
   local allow='unknown'
   if allowQueries<8 then allowQueries=allowQueries+1;local success,value=pcall(deps.query_allow,container);if success then allow=state(value)end end
   local denied={}
   for _,tag in ipairs(deny)do
    if not queried[tag]then
     queried[tag]='unknown'
     if tagQueries<32 then tagQueries=tagQueries+1;local success,value=pcall(deps.query_tag,tag);if success then queried[tag]=state(value)end end
    end
    denied[#denied+1]=queried[tag]
   end
   return deps.model.group(allow,deps.model.combine(denied,false))
  end})
  local values={};for _,group in ipairs(config.groups)do values[#values+1]=group.current end
  return{status='read',state=deps.model.combine(values,config.conditions_and),groups=values,complete=false}
 end)
 if ok then return result end
 return{status='unavailable',state='unknown',complete=false,reason=tostring(result)}
end
return Branch
