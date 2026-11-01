-- This getter was verified on native PlaySubTitle templates. No event is executed.
local Narration={}
function Narration.read(node)
 local available=false
 node:GetClass():ForEachFunction(function(func)
  if func:GetFullName():match(':K2_GetNodeDescription$')and(func:GetFunctionFlags()&0x40000000)~=0 then available=true end
 end)
 if not available then return nil,'const narration getter unavailable'end
 local ok,description=pcall(function()
  local value=node:K2_GetNodeDescription();return type(value)=='string'and value or value:ToString()
 end)
 if not ok then return nil,tostring(description)end
 local text=description:match('^播放旁白：(.*)$')
 if not text then return nil,'unrecognized narration description'end
 text=text:gsub('<[%w_]+>',''):gsub('</[%w_]*>',''):match('^%s*(.-)%s*$')
 if text==''then return nil,'empty native narration'end
 return text
end
return Narration
