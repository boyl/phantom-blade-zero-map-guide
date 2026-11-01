-- Observe one known native input registration; invoke only its normal map-view callback.
local Navigation={};Navigation.__index=Navigation
local bindPath='/Script/ProjectPBZ.PBZActivatableWidget:BindKey'
local rootPath='/Game/PBZContent/UI/UINew/System/W_Systembase.W_Systembase_C'
local proxyClass='Class /Script/JsEnv.DynamicDelegateProxy'
local function path(object)return assert(object:GetFullName():match('^%S+ (.+)$'),'native object path unavailable')end
function Navigation.new(deps,model)
 local self=setmetatable({deps=deps,captures={},order={}},Navigation)
 self.model=model.new({read=function()
  local map=deps.map.active();if map then return{identity=map:GetFullName(),region=map.CurrentDisplayMapID:ToString(),big=map.BigMapMode}end
 end,enter=function(target)return self:_enter(target)end})
 return self
end
function Navigation:start()
 assert(not self.pre,'navigation observation already started')
 local func=self.deps.find(bindPath)
 assert(func:IsValid()and(func:GetFunctionFlags()&0x400)~=0,'native map input registration unavailable')
 local expected={'StructProperty:RowHandle','BoolProperty:bDisplayActionBar','DelegateProperty:DelegateHandle','ByteProperty:InputEvent'};local count=0
 func:ForEachProperty(function(p)
  count=count+1;local full=p:GetFullName()
  assert((full:match('^(%S+)')..':'..p:GetFName():ToString())==expected[count],'native map input signature changed')
 end)
 assert(count==4,'native map input signature changed')
 self.pre,self.post=self.deps.register(bindPath,function(context,rowHandle,_,delegateHandle)
  local ok,why=pcall(function()
   if rowHandle:get().RowName:ToString()~='SwitchMap'then return end
   local root=self.deps.find(rootPath);local owner=context:get()
   if not root:IsValid()or not owner:IsValid()or not owner:IsA(root)then return end
   local value=delegateHandle:get()
   assert(type(value)=='table'and value.Object and value.Object:IsValid(),'native map callback unavailable')
   assert(value.FunctionName:ToString()=='Fire'and value.Object:GetClass():GetFullName()==proxyClass,'native map callback contract changed')
   local key=owner:GetFullName()
   local fresh=not self.captures[key]or self.captures[key].path~=path(value.Object)
   if not self.captures[key]then self.order[#self.order+1]=key end
   self.captures[key]={path=path(value.Object)}
   if #self.order>32 then self.captures[table.remove(self.order,1)]=nil end
   if fresh and self.deps.log then self.deps.log('Native SwitchMap callback captured')end
  end)
  if not ok then
   self.error=tostring(why)
   if self.error~=self.lastCaptureError and self.deps.log then self.deps.log('Native navigation capture unavailable: '..self.error)end
   self.lastCaptureError=self.error
  end
  -- No return override and no UI invocation inside native registration.
 end)
 assert(type(self.pre)=='number'and type(self.post)=='number','native observation handles unavailable')
end
function Navigation:stop()
 self.model:cancel()
 if self.pre then self.deps.unregister(bindPath,self.pre,self.post);self.pre=nil;self.post=nil end
 self.captures={};self.order={}
end
function Navigation:_callback(map)
 local bindings=map.BindKeyDelegate:GetBindings();assert(#bindings==1,'native map host is not unique')
 assert(bindings[1].FunctionName:ToString()=='BindKey','native map host callback changed')
 local owner=bindings[1].Object;assert(owner:IsValid(),'native map host expired')
 local capture=assert(self.captures[owner:GetFullName()],'native SwitchMap registration not observed')
 local object=self.deps.find(capture.path)
 assert(object:IsValid()and object:GetClass():GetFullName()==proxyClass,'native map callback expired')
 local func=self.deps.find('/Script/JsEnv.DynamicDelegateProxy:Fire');assert(func:IsValid(),'native map callback function unavailable')
 local count=0;func:ForEachProperty(function()count=count+1 end);assert(count==0,'native map callback signature changed')
 return object
end
function Navigation:_enter(target)
 local map=assert(self.deps.map.active(),'native map closed')
 local object=self:_callback(map)
 assert(map:Reflection():GetProperty('CurrentMapID'):GetFullName():match('^StrProperty '),'native cached map field changed')
 assert(map:Reflection():GetProperty('BigMapMode'):GetFullName():match('^BoolProperty '),'native cached map mode changed')
 local original=map.CurrentMapID:ToString();assert(original~=''and original:lower()~='none','native current map unavailable')
 local originalBig=map.BigMapMode
 local ok,why=pcall(function()
  map.CurrentMapID=target;map.BigMapMode=true
  assert(map.CurrentMapID:ToString()==target,'native UI target assignment failed');object:Fire()
 end)
 map.CurrentMapID=original
 assert(map.CurrentMapID:ToString()==original,'native UI player-map restoration failed')
 local shown=not map.BigMapMode and map.CurrentDisplayMapID:ToString():lower()==target:lower()
 if not ok or not shown then map.BigMapMode=originalBig end
 assert(ok,tostring(why))
 if shown then map.WB_PlayerIcon:SetVisibility(1);map.SlotWidgetGroup:RemoveWidget(map.WB_PlayerIcon)end
 return shown
end
function Navigation:request(map,info)
 local allowed=self.deps.map.allowed(map);local chosen,located
 for i,source in ipairs(info.sources or{})do
  if source.location_status~='unavailable'then
  located=true
  if allowed[source.map_id:lower()]then return self.model:request({unlocked=true,same_region=true})end
  if not chosen and info.source_map_unlocked and info.source_map_unlocked[i]==true then chosen=source end
  end
 end
 if not chosen then
  if not located then return self.model:request({})end
  local plan={};if info.map_unlock_status=='read'then plan.unlocked=false end
  return self.model:request(plan)
 end
 local target=self.deps.map.region(map,chosen.map_id)
 if not target then return self.model:request({})end
 self:_callback(map) -- Fail before changing the view if registration was missed.
 return self.model:request({identity=map:GetFullName(),target=target,origin_region=map.CurrentDisplayMapID:ToString(),origin_big=map.BigMapMode,unlocked=true})
end
function Navigation:step()
 local ok,why=pcall(self.model.step,self.model)
 if not ok then self.error=tostring(why);self.model:cancel()end
 return self.model.status
end
function Navigation:cancel()self.model:cancel()end
return Navigation
