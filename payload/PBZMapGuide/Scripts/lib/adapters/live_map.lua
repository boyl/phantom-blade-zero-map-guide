local Map={}
local slots={{'AdvancedSlotClass_HeiShi','blackstone'},{'AdvancedSlotClass_Hupo','amber'},{'AdvancedSlotClass_Flower','memory_flower'},{'AdvancedSlotClass_PrimaryItem','item'},{'AdvancedSlotClass_YaoshiItem','key'},{'AdvancedSlotClass_Challenge',false}}
function Map.visible(map)
 if not map:IsValid()then return false end
 local id=map.CurrentDisplayMapID:ToString()
 if id==''or id:lower()=='none'or not map.MapClickSurface:IsValid()then return false end
 local outer=map:GetOuter();if not outer:IsValid()then return false end
 local host=outer:GetOuter();if not host:IsValid()then return false end
 local hostClass=StaticFindObject('/Script/CommonUI.CommonActivatableWidget')
 assert(hostClass:IsValid(),'native activatable map host contract unavailable')
 -- FindObjects also returns blueprint-template children whose outer is a UClass.
 -- Never dispatch an instance UI function on that metadata object.
 if not host:IsA(hostClass)or not host:IsActivated()then return false end
 local parent=map
 for _=1,10 do
  local visibility=parent:GetVisibility()
  if visibility==1 or visibility==2 then return false end
  parent=parent:GetParent();if not parent:IsValid()then break end
 end
 return true
end
function Map.active()
 for _,map in ipairs(FindObjects(8,'WB_MapNew_C',nil,0,EObjectFlags.RF_ClassDefaultObject,false)or{})do
  if Map.visible(map)then return map end
 end
end
function Map.allowed(map)
 local current=map.CurrentDisplayMapID:ToString():lower()
 local allowed={[current]=true}
 if map.MapIDAsset:IsValid()then
  map.MapIDAsset.Maps:ForEach(function(key,value)
   if key:get():ToString():lower()~=current then return end
   local row=value:get()
   local field
   row:GetProperty():GetStruct():ForEachProperty(function(property)
    local name=property:GetFName():ToString()
    if name=='AllowedMapID' or name:match('^AllowedMapID_%d+_%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$')then
     assert(not field,'ambiguous map group field');field=name
    end
   end)
   assert(field,'map group field unavailable')
   row[field]:ForEach(function(_,name)allowed[name:get():ToString():lower()]=true end)
  end)
 end
 return allowed
end
function Map.region(map,id)
 if not map.MapIDAsset:IsValid()then return nil end
 local matches={};local wanted=id:lower()
 map.MapIDAsset.Maps:ForEach(function(key,value)
  local owner=key:get():ToString();local row=value:get();local field
  row:GetProperty():GetStruct():ForEachProperty(function(property)
   local name=property:GetFName():ToString()
   if name=='AllowedMapID'or name:match('^AllowedMapID_%d+_%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$')then
    assert(not field,'ambiguous map group field');field=name
   end
  end)
  assert(field,'map group field unavailable')
  if owner:lower()==wanted then matches[owner]=true end
  row[field]:ForEach(function(_,parameter)if parameter:get():ToString():lower()==wanted then matches[owner]=true end end)
 end)
 local found;for owner in pairs(matches)do if found then return nil end;found=owner end
 return found
end
function Map.selection(map,records,lockInfo,lockDeps)
 local selected=map.SlotWidgetGroup:GetSelectedSlot()
 if not selected:IsValid()then return nil end
 local lockClass=StaticFindObject('/Game/PBZContent/UI/InGame/Map/LockObj/W_MapLockSlot.W_MapLockSlot_C')
 if lockClass:IsValid() and selected:IsA(lockClass)then return lockInfo.read(selected,lockDeps)end
 for _,pair in ipairs(slots)do
  local cls=map[pair[1]]
  if cls:IsValid() and selected:IsA(cls)then
   local world=selected.Location
   local position={x=world.X,y=world.Y,z=world.Z}
   local id=selected.OwnMapID:ToString():lower()
   local matches={}
   for _,record in ipairs(records)do
    if (not pair[2] or record.category==pair[2]) and record.map_id:lower()==id and record.world.x==position.x and record.world.y==position.y and record.world.z==position.z then matches[#matches+1]=record end
   end
   if #matches>0 then return lockDeps.service:records(matches)end
   return nil
  end
 end
end
return Map
