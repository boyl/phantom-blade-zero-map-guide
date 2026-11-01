local Nearest={}
-- A geometric candidate only. Does not claim a walkable route or teleport access.
function Nearest.bell(source,bells)
 if source.location_status=='unavailable'then return nil end
 local nearest,distance
 for _,bell in ipairs(bells) do
  if bell.map_id:lower()==source.map_id:lower() then
   local a,b=source.world,bell.world
   local squared=(a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2
   if distance==nil or squared<distance then nearest=bell;distance=squared end
  end
 end
 return nearest,distance and math.sqrt(distance)
end
return Nearest
