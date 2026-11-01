-- Resolve only the exact native saved actor ID. Never spawn, initialize or interact.
local Source={}
local classes={
 {path='/Game/PBZContent/Blueprint/Item/Device/BP_Chest.BP_Chest_C',kind='chest'},
 {path='/Game/PBZContent/Blueprint/Item/Device/BP_Rubbish.BP_Rubbish_C',kind='pickup'},
 {path='/Game/PBZContent/VFX/SceneFX/Common/BP_FlowInteract_MemoryFlower.BP_FlowInteract_MemoryFlower_C',kind='flower'},
}
local fields={UseLegacyType='BoolProperty',LootLevel='IntProperty',FlowerItem='StrProperty',FlowerQuestBranch='NameProperty',['Loot Item ID']='NameProperty',['Item ID']='NameProperty',['Not Interact']='BoolProperty',RubbishType='ByteProperty'}
local rewards={PickupMap='number',PickupMaps='number',GetWeapons='boolean',ReallyGetWeapons='boolean'}
function Source.lookup(id,deps)
 local functionPath='/Script/ProjectPBZ.PBZLevelActorManager:GetActorByID'
 local func=deps.find(functionPath);assert(func and func:IsValid(),'native actor lookup unavailable')
 local expected={ActorID='NameProperty',ActorClass='ClassProperty',ReturnValue='ObjectProperty'}
 local count=0;local metadata={};local overflow=false
 func:ForEachProperty(function(p)
  if #metadata>=8 then overflow=true;return end
  metadata[#metadata+1]={key=p:GetFName():ToString(),full=p:GetFullName()}
 end)
 assert(not overflow,'native actor lookup metadata bound')
 for _,p in ipairs(metadata)do
  local key=p.key;local kind=expected[key]
  assert(kind and p.full:match('^'..kind..' '),'native actor lookup signature changed')
  expected[key]=nil;count=count+1
 end
 assert(count==3,'native actor lookup signature incomplete')
 local cls=deps.find('/Script/Engine.Actor');assert(cls and cls:IsValid(),'native actor class unavailable')
 local manager=deps.manager();assert(manager and manager:IsValid(),'native actor manager unavailable')
 return manager:GetActorByID(deps.name(id),cls)
end
function Source.read(record,deps)
 if not record.pickup_id then return{status='not_applicable'}end
 local ok,result=pcall(function()
  local actor=deps.lookup(record.pickup_id)
  if not actor or not actor:IsValid()then return{status='not_loaded'}end
  local path=actor:GetFullName()
  assert(path:find(':PersistentLevel.',1,true),'source lookup did not return a level actor')
  local kind
  for _,spec in ipairs(classes)do
   local cls=deps.find(spec.path)
   if cls and cls:IsValid()and actor:IsA(cls)then assert(not kind,'ambiguous source type');kind=spec.kind end
  end
  if not kind then return{status='unsupported'}end
  local values,configured={},{};local seen={}
  local metadata={};local overflow=false
  actor:GetClass():ForEachProperty(function(p)
   local key=p:GetFName():ToString()
   if fields[key]or rewards[key]then
    if #metadata>=32 then overflow=true;return end
    metadata[#metadata+1]={key=key,full=p:GetFullName()}
   end
  end)
  assert(not overflow,'native source field metadata bound')
  for _,p in ipairs(metadata)do
   local key=p.key;local expected=fields[key]
   if expected then
    assert(not seen[key],'duplicate native source field');seen[key]=true
    assert(p.full:match('^'..expected..' '),'native source field type changed')
    local value=actor[key]
    if expected=='BoolProperty'then assert(type(value)=='boolean','invalid native source boolean')
    elseif expected=='IntProperty'or expected=='ByteProperty'then assert(type(value)=='number'and value%1==0,'invalid native source integer')
    else value=value:ToString()end
    values[key]=value
   elseif rewards[key]then
    local ok,items=pcall(function()
     assert(p.full:match('^MapProperty '),'native reward configuration type changed')
     local map=actor[key];assert(#map<=256,'native reward configuration bound');local result={};local overflow=false
     map:ForEach(function(k,v)
      if #result>=256 then overflow=true;return end
      local value=v:get()
      result[#result+1]={id=k:get():ToString(),value=value}
     end)
     assert(not overflow,'native reward iteration bound')
     for _,item in ipairs(result)do
      assert(type(item.value)==rewards[key],'invalid native reward configuration value')
      if type(item.value)=='number'then assert(item.value%1==0,'invalid native reward count')end
     end
     return result
    end)
    configured[key]=ok and{status='read',items=items}or{status='unavailable',reason=tostring(items)}
   end
  end
  return{status='read',kind=kind,fields=values,rewards=configured}
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
return Source
