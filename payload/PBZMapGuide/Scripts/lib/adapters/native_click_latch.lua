-- Native click clears only the Mod-owned receiver's sentinel child.
-- Sampling that state needs no global function hook or Lua delegate callback.
local Events={}
Events.__index=Events
function Events.new(deps)return setmetatable({deps=deps,entries={},active=true},Events)end
function Events:bindClick(source,receiver,callback)
 assert(self.active and source:IsValid() and receiver:IsValid(),'active owned click objects required')
 local key=receiver:GetAddress();assert(not self.entries[key],'receiver already bound')
 assert(receiver:GetChildrenCount()==0,'receiver must be an empty owned container')
 local entry={source=source,receiver=receiver,callback=callback,active=true}
 receiver:AddChild(self.deps.sentinel(receiver))
 source.OnClicked:Add(receiver,self.deps.name('ClearChildren'))
 self.entries[key]=entry
 local function detach()
  if not entry.active then return end
  entry.active=false;self.entries[key]=nil
  if source:IsValid() and receiver:IsValid()then source.OnClicked:Remove(receiver,self.deps.name('ClearChildren'))end
 end
 entry.detach=detach;return detach
end
function Events:poll()
 if not self.active then return end
 local entries={};for _,entry in pairs(self.entries)do entries[#entries+1]=entry end
 for _,entry in ipairs(entries)do
  if entry.active and entry.receiver:IsValid() and entry.receiver:GetChildrenCount()==0 then
   entry.receiver:AddChild(self.deps.sentinel(entry.receiver))
   local ok,message=pcall(entry.callback)
   if not ok then self.deps.report('UI click failed: '..tostring(message))end
  end
 end
end
function Events:stop()
 if not self.active then return end;self.active=false
 local entries={};for _,entry in pairs(self.entries)do entries[#entries+1]=entry end
 for _,entry in ipairs(entries)do entry.detach()end
end
return Events
