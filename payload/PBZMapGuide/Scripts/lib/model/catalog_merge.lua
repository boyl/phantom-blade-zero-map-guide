-- Definitions extend search coverage; only original map records carry coordinates.
local Merge={}
local equipment={weapon=true,phantom_edge=true,accessory=true,medicine=true}
local function identity(record)
 if equipment[record.category]then return record.item_id and record.category..'/'..record.item_id:lower()or nil end
 local id=record.inventory_id or record.item_id
 return id and'inventory/'..id:lower()or nil
end
function Merge.combine(records,definitions)
 local result,seen={},{}
 local report={map_records=#records,definitions=#definitions,added=0,matched=0,duplicates=0}
 for _,record in ipairs(records)do
  result[#result+1]=record
  local key=identity(record);if key then seen[key]=true end
  if record.inventory_id then seen['inventory/'..record.inventory_id:lower()]=true end
 end
 local defined={}
 for _,definition in ipairs(definitions)do
  local id=definition.id;assert(type(id)=='string'and id~=''and id:lower()~='none','definition ID required')
  local namespace=definition.namespace;assert(namespace=='inventory'or equipment[namespace],'unsupported definition namespace')
  local key=namespace..'/'..id:lower()
  if defined[key]then report.duplicates=report.duplicates+1
  elseif seen[key]then report.matched=report.matched+1
  else
   local category=namespace=='inventory'and definition.category or namespace
   assert(category=='key'or category=='item'or equipment[category],'unsupported definition category')
   result[#result+1]={catalog_only=true,category=category,item_id=id,
    inventory_id=namespace=='inventory'and id or nil,map_id='',location_status='unavailable',
    requirements={kind='unknown'},evidence={source='native item definition'}}
   report.added=report.added+1
  end
  defined[key]=true
 end
 return result,report
end
return Merge
