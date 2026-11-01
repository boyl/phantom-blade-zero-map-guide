-- Read mouse state on the game thread; no gameplay input is synthesized or consumed.
local Pointer={}
function Pointer.read(map,layout,name,needsPosition)
 local controller=map:GetOwningPlayer()
 if not controller:IsValid()then return{down=false}end
 local down=controller:IsInputKeyDown({KeyName=name('LeftMouseButton')})
 local result={down=down}
 if needsPosition then
  local point=layout:GetMousePositionOnViewport(map)
  result.x,result.y=point.X,point.Y
 end
 return result
end
return Pointer
