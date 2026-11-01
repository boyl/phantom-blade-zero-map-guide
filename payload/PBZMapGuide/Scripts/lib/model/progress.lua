-- Completion is a fresh read-only snapshot, independent of accessibility.
local Progress={}
local cycleCategories={weapon=true,phantom_edge=true,accessory=true,medicine=true,memory_flower=true}
function Progress.scope(record)return cycleCategories[record.category]and'item_cycle'or'location'end
function Progress.countable(record,snapshot)
 return not(record.category=='memory_flower'and record.item_id and(snapshot.flower_countable or{})[record.item_id:lower()]==false)
end
function Progress.completion(record,snapshot)
 if cycleCategories[record.category]then
  if not snapshot.ready[record.category] or snapshot.cycle==nil or not record.item_id then return 'unknown'end
  local acquired=snapshot.acquired[record.category][record.item_id:lower()]
  return acquired==snapshot.cycle and 'collected' or 'missing'
 end
 local present,unknown=false,false
 local function channel(id,values)
  if not id then return false end
  present=true
  local value=values and values[id:lower()]
  assert(value==nil or type(value)=='boolean','completion evidence must be boolean or unknown')
  if value==nil then unknown=true end
  return value==true
 end
 if channel(record.pickup_id,snapshot.actor_saved)then return 'collected'end
 if channel(record.mob_domain,snapshot.mob_awards)then return 'collected'end
 for _,id in ipairs(record.node_ids or{})do if channel(id,snapshot.executed_nodes)then return 'collected'end end
 if not present or unknown then return 'unknown'end
 return 'missing'
end
function Progress.summary(records,snapshot)
 local result={total=0,collected=0,missing=0,unknown=0,scope='unknown'}
 local entries={};local rank={missing=1,unknown=2,collected=3}
 for index,record in ipairs(records)do
  if Progress.countable(record,snapshot)then
  local scope=Progress.scope(record)
  if result.scope=='unknown'then result.scope=scope elseif result.scope~=scope then result.scope='mixed'end
  local key
  if scope=='item_cycle' and record.item_id then key=record.category..'/'..record.item_id:lower()
  elseif scope=='location' and record.pickup_id then key=(record.map_id or''):lower()..'/actor/'..record.pickup_id:lower()
  else key='record/'..index end
  local status=Progress.completion(record,snapshot)
  if not entries[key]or rank[status]>rank[entries[key]]then entries[key]=status end
  end
 end
 for _,status in pairs(entries)do result.total=result.total+1;result[status]=result[status]+1 end
 return result
end
return Progress
