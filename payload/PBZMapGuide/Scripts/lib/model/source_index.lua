local Index={}
Index.__index=Index
local function key(category,id) return category..'/'..id:lower() end
local function finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
function Index.build(records)
 local self=setmetatable({items={},inventory_items={},pickups={},maps={},records=records,unresolved=0,unidentified=0,total=#records},Index)
 for _,record in ipairs(records) do
  assert(type(record.map_id)=='string' and record.map_id~='', 'source map ID required')
  local point=record.world
  assert(point and finite(point.x) and finite(point.y) and finite(point.z), 'finite world coordinates required')
  local map=record.map_id:lower();self.maps[map]=self.maps[map]or{};self.maps[map][#self.maps[map]+1]=record
  if record.item_id then
   assert(type(record.item_id)=='string' and record.item_id~='', 'item ID required')
   local id=key(record.category,record.item_id)
   self.items[id]=self.items[id] or {}
   self.items[id][#self.items[id]+1]=record
  else self.unresolved=self.unresolved+1 end
  if record.inventory_id then
   local id=record.inventory_id:lower()
   self.inventory_items[id]=self.inventory_items[id] or {}
   self.inventory_items[id][#self.inventory_items[id]+1]=record
  end
  if record.pickup_id then
   assert(type(record.pickup_id)=='string' and record.pickup_id~='', 'pickup ID required')
   local id=key(record.map_id:lower(),record.pickup_id)
   self.pickups[id]=self.pickups[id] or {}
   self.pickups[id][#self.pickups[id]+1]=record
  elseif not record.item_id then self.unidentified=self.unidentified+1 end
 end
 return self
end
function Index:at(mapId,point,category)
 local matches={}
 for _,record in ipairs(self.maps[mapId:lower()]or{})do
  local p=record.world
  if (not category or record.category==category)and p.x==point.x and p.y==point.y and p.z==point.z then matches[#matches+1]=record end
 end
 return matches
end
function Index:resolveIdentity(record)
 if record.category~='item' or not record.item_id then return record end
 local types={weapon=true,phantom_edge=true,accessory=true,medicine=true}
 local candidate
 for _,other in ipairs(self:at(record.map_id,record.world))do
  if types[other.category]and other.item_id and other.item_id:lower()==record.item_id:lower()
   and(not record.pickup_id or not other.pickup_id or record.pickup_id:lower()==other.pickup_id:lower())then
   if candidate and candidate.category~=other.category then return nil,'ambiguous'end
   candidate=other
  end
 end
 return candidate or record
end
function Index:findPickup(mapId,pickupId)
 return self.pickups[key(mapId:lower(),pickupId)] or {}
end
function Index:findInventory(itemId)
 return self.inventory_items[itemId:lower()] or {}
end
function Index:find(category,id)
 return self.items[key(category,id)] or {}
end
function Index:partition(records,currentMap)
 local current,other={},{}
 for _,record in ipairs(records) do
  local target=record.map_id:lower()==currentMap:lower() and current or other
  target[#target+1]=record
 end
 return current,other
end
return Index
