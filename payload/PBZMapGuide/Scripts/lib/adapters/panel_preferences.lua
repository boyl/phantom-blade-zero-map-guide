-- Mod-owned display preference only; never reads or writes the game's save directory.
local Preferences={}
function Preferences.new(path)
 return{
  load=function()
   local file=io.open(path,'r');if not file then return nil end
   local line=file:read(128);file:close()
   local x,y=(line or''):match('^PBZ_POSITION_1 ([%d%.]+) ([%d%.]+)%s*$')
   x,y=tonumber(x),tonumber(y)
   if x and y and x>=0 and x<=1 and y>=0 and y<=1 then return{x=x,y=y}end
  end,
  save=function(position)
   local file,message=io.open(path,'w');if not file then return nil,message end
   local ok,err=file:write(position and string.format('PBZ_POSITION_1 %.6f %.6f\n',position.x,position.y)or'PBZ_POSITION_DEFAULT\n')
   local closed,closeErr=file:close();return ok and closed,err or closeErr
  end,
 }
end
return Preferences
