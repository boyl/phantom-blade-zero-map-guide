-- A Mod-owned canvas inside the resized native map content, never the viewport-sized Gadget sibling.
local Layer={}
function Layer.create(map,deps)
 local parent=map.MapOverlay;assert(parent:IsValid(),'native map content unavailable')
 if deps.report then deps.report('Source marker content parent='..parent:GetClass():GetFullName())end
 local canvasClass=deps.find('/Script/UMG.CanvasPanel');local overlayClass=deps.find('/Script/UMG.Overlay')
 assert(canvasClass:IsValid()and overlayClass:IsValid(),'native map layer classes unavailable')
 local canvas=deps.construct(canvasClass,map);assert(canvas:IsValid(),'source canvas unavailable')
 local ok,why=pcall(function()
  local slot=parent:AddChild(canvas);assert(slot:IsValid(),'source canvas parent slot unavailable')
  if parent:IsA(canvasClass)then
   slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
   slot:SetPosition({X=0,Y=0});slot:SetSize({X=0,Y=0});slot:SetZOrder(49)
  elseif parent:IsA(overlayClass)then
   slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
  else error('unsupported native map content panel')end
  canvas:SetVisibility(3)
 end)
 if not ok then canvas:RemoveFromParent();error(why)end
 return canvas
end
return Layer
