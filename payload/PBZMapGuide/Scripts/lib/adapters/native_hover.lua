-- Keeps only primitive selection keys. Callbacks may change the brief, never the pinned target.
local Hover={};Hover.__index=Hover
function Hover.new(deps)return setmetatable({deps=deps},Hover)end
function Hover:reset()self.key=nil;self.clickedKey=nil end
function Hover:update(map,target,blocked)
 if blocked then return end
 local key=self.deps.readKey(map);local clickedKey=target and target.key or nil
 if key==self.key and clickedKey==self.clickedKey then return end
 self.key=key;self.clickedKey=clickedKey
 local info
 if key~=''and key~='None'then info=self.deps.readInfo(map)end
 if info and info.key~=clickedKey then self.deps.show(info)
 elseif target then self.deps.restore(target)
 else self.deps.hide()end
end
return Hover
