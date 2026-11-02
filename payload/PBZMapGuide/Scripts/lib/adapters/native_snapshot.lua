-- Copy primitives only. No borrowed engine rows survive this function.
local Snapshot={}
local fields={weapon='MainWeaponInfos',phantom_edge='ShaqiWeaponInfos',accessory='Accessories',medicine='MedicineInfos',memory_flower='Inventories'}
function Snapshot.read(records,context,name)
 local result={ready={},partial={},acquired={},owned={weapon={},phantom_edge={}},actor_saved={},mob_awards={},executed_nodes={},errors={}}
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
     local cycle=value:get().AcquiredCycle
     rows[#rows+1]={id=key:get():ToString():lower(),cycle=type(cycle)=='number'and cycle or nil}
    end)
    local acquired,present,invalid={},{},{}
    for _,row in ipairs(rows)do
     if row.id==''or row.id=='none'then invalid[#invalid+1]='invalid_id'
     else
      present[row.id]=true
      if type(row.cycle)=='number'and row.cycle>=0 and row.cycle%1==0 then acquired[row.id]=row.cycle
      else invalid[#invalid+1]=row.id end
     end
    end
    return{acquired=acquired,present=present,invalid=invalid}
   end)
   if ok then
    result.acquired[category]=values.acquired;result.ready[category]=true
    result.partial[category]=#values.invalid>0
    for _,id in ipairs(values.invalid)do result.errors['inventory/'..category..'/'..id]='invalid acquisition record'end
    if result.owned[category]then result.owned[category]=values.present end
   end
  end
 end
 result.ready.inventory=result.ready.memory_flower
 result.acquired.inventory=result.acquired.memory_flower
 result.partial.inventory=result.partial.memory_flower
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
