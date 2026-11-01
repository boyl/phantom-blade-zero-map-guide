-- Mirrors MapItemCompletionCalc: multi-petal whole flowers are excluded from map totals.
-- Keep all source records intact; this table affects collection counting only.
local Flower={}
function Flower.read(records,backpack,deps)
 local result={}
 if not backpack then return result end
 local object=deps.find('/Script/ProjectPBZ.EItemTypes')
 if not object:IsValid()then return result end
 local flowerType
 object:ForEachName(function(name,value)if name:ToString():match('([^:]+)$')=='MemoryFlower'then flowerType=value end end)
 if flowerType==nil then return result end
 for _,record in ipairs(records)do
  if record.category=='memory_flower'and record.item_id then
   local id=record.item_id:lower()
   if result[id]==nil then
    -- Materialize the enum before invoking another engine function.
    local itemType=backpack:GetPropData(deps.name(record.item_id)).ItemType
    assert(type(itemType)=='number','invalid memory flower item type')
    if itemType==flowerType then
     local petals=backpack:GetOrderedMemoryFlowerPetals(deps.name(record.item_id))
     result[id]=#petals<=1
    else result[id]=true end
   end
  end
 end
 return result
end
return Flower
