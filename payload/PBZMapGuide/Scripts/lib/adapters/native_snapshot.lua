-- Copy primitives only. No borrowed engine rows survive this function.
local Snapshot={}
local fields={weapon='MainWeaponInfos',phantom_edge='ShaqiWeaponInfos',accessory='Accessories',medicine='MedicineInfos',memory_flower='Inventories'}
function Snapshot.read(records,context,name)
 local result={ready={},acquired={},owned={weapon={},phantom_edge={}},actor_saved={},mob_awards={},executed_nodes={},errors={}}
 local function read(key,fn)
  local ok,value=pcall(fn)
  if ok then return value,true end
  result.errors[key]=tostring(value);return nil,false
 end
 if context.game then
  result.cycle=read('cycle',function()
   local cycle=context.game:GetCycleCount()
   assert(type(cycle)=='number' and cycle>=0 and cycle%1==0,'invalid current cycle')
   return cycle
  end)
 end
 for category,field in pairs(fields)do
  result.acquired[category]={};result.ready[category]=false
  if context.backpack then
   local values,ok=read('inventory/'..category,function()
    local rows={}
    context.backpack[field]:ForEach(function(key,value)
     rows[#rows+1]={id=key:get():ToString():lower(),cycle=value:get().AcquiredCycle}
    end)
    local acquired={}
    for _,row in ipairs(rows)do
     assert(type(row.cycle)=='number'and row.cycle%1==0,'invalid acquisition cycle')
     acquired[row.id]=row.cycle
    end
    return acquired
   end)
   if ok then
    result.acquired[category]=values;result.ready[category]=true
    if result.owned[category]then for id in pairs(values)do result.owned[category][id]=true end end
   end
  end
 end
 local executed
 if context.events then executed=read('executed_nodes',function()
  local values={};context.events.ExecuteNodeGuid:ForEach(function(key)values[key:get():ToString():lower()]=true end)
  return values
 end)end
 local actorRead,mobRead={},{}
 for _,record in ipairs(records)do
  if record.pickup_id and context.actors then
   local id=record.pickup_id:lower()
   if not actorRead[id]then
    actorRead[id]=true
    result.actor_saved[id]=read('actor/'..id,function()
     local saved=context.actors:HasSaveDataByActorID(name(record.pickup_id))
     assert(type(saved)=='boolean','invalid actor completion');return saved
    end)
   end
  end
  if record.mob_domain and context.game then
   local id=record.mob_domain:lower()
   if not mobRead[id]then
    mobRead[id]=true
    result.mob_awards[id]=read('mob/'..id,function()
     local done=context.game.CompleteAddItemMobDomainNames:Contains(name(record.mob_domain))
     assert(type(done)=='boolean','invalid mob completion');return done
    end)
   end
  end
  if executed then for _,id in ipairs(record.node_ids or{})do result.executed_nodes[id:lower()]=executed[id:lower()]==true end end
 end
 return result
end
return Snapshot
