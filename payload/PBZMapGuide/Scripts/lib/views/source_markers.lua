-- All objects managed here belong to the Mod. Native slot groups are untouched.
local View={}
View.__index=View
local function vector(value)return{X=value.X,Y=value.Y}end
function View.new(deps,geometry,points,routes)return setmetatable({deps=deps,geometry=geometry,points=points,routes=routes,items={}},View)end
function View:clear(preserveView)
 if self.routes then self.routes:clear()end;self.routeShown=nil
 for _,item in ipairs(self.items)do
  if item.label and item.label:IsValid()then item.label:RemoveFromParent()end
  local widget=item.widget
  if widget:IsValid() and (not item.initialized or widget:GetSlotID():ToString()==item.id) then
   if item.image and item.image:IsValid()then item.image:SetColorAndOpacity(item.color)end
   if not item.attached or widget:GetParent():IsValid()then
    if self.map and self.map:IsValid()then self.map:RemoveWidget(widget)else widget:RemoveFromParent()end
   end
  end
 end
 self.items={}
 if self.layer and self.layer:IsValid()then self.layer:RemoveFromParent()end
 self.layer=nil;self.layerVisibility=nil
 if not preserveView and self.focus and self.focus.slot:IsValid() and self.map and self.map:IsValid() and self.map.CurrentDisplayMapID:ToString()==self.focus.mapId then
  local current=vector(self.focus.slot:GetPosition())
  local unchangedSize=not self.focus.size or self.geometry.same(vector(self.focus.slot:GetSize()),self.focus.size)
  if unchangedSize and self.geometry.same(current,self.focus.applied)then self.focus.slot:SetPosition(self.focus.previous)end
 end
 self.focus=nil;self.map=nil;self.target=nil
end
function View:setRoute(route,allowed)
 if not self.routes or route==self.routeShown then return end
 self.routeShown=route
 self.routes:show(self.map,self.layer,route,allowed)
end
function View:update()
 if not self.map or not self.map:IsValid()then self:clear();return end
 if #self.items==0 then return end
 assert(self.layer and self.layer:IsValid(),'source map layer unavailable')
 local visibility=self.map.BigMapMode and 1 or 3
 if visibility~=self.layerVisibility then self.layer:SetVisibility(visibility);self.layerVisibility=visibility end
 local subsystem
 for _,item in ipairs(self.items)do
  if not item.widget:IsValid() or item.widget:GetSlotID():ToString()~=item.id then error('source widget was released or reused')end
  assert(item.slot:IsValid()and item.labelSlot:IsValid()and item.label:IsValid(),'source canvas slot unavailable')
  if not item.uv then
   subsystem=subsystem or self.deps.mapSystem()
   local world=item.source.world
   item.uv=vector(subsystem:ProjectWorldLocationToMap({X=world.x,Y=world.y,Z=world.z},self.deps.name(item.source.map_id)))
  end
  if not item.anchored then
   local anchors={Minimum={X=item.uv.X,Y=item.uv.Y},Maximum={X=item.uv.X,Y=item.uv.Y}}
   item.slot:SetAnchors(anchors);item.labelSlot:SetAnchors(anchors)
   item.slot:SetPosition({X=0,Y=0});item.labelSlot:SetPosition({X=0,Y=-40});item.anchored=true
  end
 end
end
function View:show(map,target,allowed,focus)
 self:clear(focus==false);self.map=map;self.target=target.key
 local layout=self.deps.layout()
 local sources,other=self.points.partition(target,allowed)
 assert(#sources<=64,'source marker count exceeds supported UI budget')
 local ok,message=pcall(function()
  if #sources>0 then
   self.layer=self.deps.sourceLayer(map)
   if self.deps.report then self.deps.report('Source markers layout=native_layer_anchors')end
  end
  for _,entry in ipairs(sources)do
   local source=entry.source
   local world=source.world
   local widget=map:CreateWidget(map.AdvancedSlotClass_PrimaryItem,{X=world.x,Y=world.y,Z=world.z})
   assert(widget:IsValid(),'native source widget unavailable')
   assert(not widget:GetParent():IsValid(),'native pool returned an attached widget; preserved')
   local item={widget=widget,source=source,id='PBZMapGuide_Source_'..tostring(#self.items+1)}
   self.items[#self.items+1]=item
   widget.OwnMapID=self.deps.name(source.map_id)
   widget:InitWidget(self.deps.text('获取处：'..entry.title),self.deps.name(item.id))
   item.initialized=true
   widget:SetRenderScale({X=2,Y=2});widget:SetRenderOpacity(1);widget:SetVisibility(3)
   local image=widget.Image_29
   if type(image.IsValid)=='function' and image:IsValid()then
    local c=image.ColorAndOpacity;item.image=image;item.color={R=c.R,G=c.G,B=c.B,A=c.A}
    image:SetColorAndOpacity({R=0.1,G=0.9,B=1,A=1})
   end
   self.layer:AddChild(widget)
   item.attached=true
   item.slot=layout:SlotAsCanvasSlot(widget)
   item.slot:SetAlignment({X=0.5,Y=0.5});item.slot:SetSize({X=52,Y=52});item.slot:SetZOrder(49)
   local label=self.deps.construct(self.deps.find('/Script/UMG.TextBlock'),map)
   assert(label:IsValid(),'source label unavailable');item.label=label
   label:SetText(self.deps.text('获取处：'..entry.title))
   local font=label.Font;font.Size=18;label:SetFont(font)
   label:SetShadowColorAndOpacity({R=0,G=0,B=0,A=1});label:SetShadowOffset({X=2,Y=2})
   label:SetColorAndOpacity({SpecifiedColor={R=0.2,G=1,B=1,A=1},ColorUseRule=0})
   label:SetVisibility(3);self.layer:AddChild(label)
   item.labelSlot=layout:SlotAsCanvasSlot(label)
   item.labelSlot:SetAutoSize(true);item.labelSlot:SetAlignment({X=0.5,Y=1});item.labelSlot:SetZOrder(55)
  end
  self:update()
  if focus~=false and self.items[1]then
   local slot=layout:SlotAsCanvasSlot(map.MapOverlay)
   assert(slot:IsValid(),'source map canvas slot unavailable')
   local size=vector(slot:GetSize());local pixels=vector(layout:GetViewportSize(map));local dpi=layout:GetViewportScale(map)
   assert(type(dpi)=='number' and dpi>0,'viewport DPI unavailable')
   local point=self.geometry.point(self.items[1].uv,size)
   local previous=vector(slot:GetPosition())
   self.focus={slot=slot,mapId=map.CurrentDisplayMapID:ToString(),size=size,previous=previous,applied=self.geometry.pan(point,size,{X=pixels.X/dpi,Y=pixels.Y/dpi})}
   slot:SetPosition(self.focus.applied)
  end
 end)
 if not ok then self:clear();error(message)end
 return #self.items,#other
end
return View
