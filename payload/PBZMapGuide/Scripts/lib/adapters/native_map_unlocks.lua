-- Same policy as native Map.initUnlockMapIds: activated bells determine unlocked sub-map IDs.
local Unlocks={}
function Unlocks.read(bell,name)
 local values=bell.ActivateBellIDs;assert(#values<=512,'activated bell bound')
 local ids={}
 values:ForEach(function(_,parameter)ids[#ids+1]=parameter:get():ToString()end)
 -- End the borrowed array iteration before native data getters.
 local maps,unresolved={},0
 for _,id in ipairs(ids)do
  assert(id~=''and id~='None','activated bell ID unavailable')
  local map=bell:GetBellData(name(id)).MapID:ToString()
  if map==''or map:lower()=='none'then unresolved=unresolved+1
  else maps[map:lower()]=true end
 end
 return{status=unresolved>0 and'partial'or'read',maps=maps,unresolved=unresolved}
end
return Unlocks
