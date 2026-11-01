-- Same policy as native Map.initUnlockMapIds: activated bells determine unlocked sub-map IDs.
local Unlocks={}
function Unlocks.read(bell,name)
 local values=bell.ActivateBellIDs;assert(#values<=512,'activated bell bound')
 local ids={}
 values:ForEach(function(_,parameter)ids[#ids+1]=parameter:get():ToString()end)
 -- End the borrowed array iteration before native data getters.
 local maps={}
 for _,id in ipairs(ids)do
  assert(id~=''and id~='None','activated bell ID unavailable')
  local map=bell:GetBellData(name(id)).MapID:ToString()
  assert(map~=''and map~='None','activated bell map unavailable')
  maps[map:lower()]=true
 end
 return{status='read',maps=maps}
end
return Unlocks
