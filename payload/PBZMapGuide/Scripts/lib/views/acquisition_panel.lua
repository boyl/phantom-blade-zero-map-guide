local Panel={}
Panel.__index=Panel
function Panel.new(deps,map,events)
 local self=setmetatable({deps=deps,map=map,expanded=false,layoutPasses=2},Panel)
 local ok,message=pcall(function()
 self.border=deps.construct(deps.find('/Script/UMG.Border'),map)
 self.border:SetPadding({Left=14,Top=12,Right=14,Bottom=12})
 self.border:SetBrushColor(deps.theme and deps.theme.colors.panel or{R=0.015,G=0.025,B=0.03,A=0.92})
 self.border:SetVisibility(1)
 self.root=deps.construct(deps.find('/Script/UMG.VerticalBox'),map);self.border:AddChild(self.root)
 self.label=deps.construct(deps.find('/Script/UMG.TextBlock'),map)
 local font=self.label.Font;font.Size=18;self.label:SetFont(font)
 self.label:SetAutoWrapText(true)
 self.label:SetColorAndOpacity({SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0})
 if deps.theme then deps.theme:text(self.label,18)end
 self.label:SetVisibility(3)
 self.root:AddChild(self.label)
 self.more=deps.construct(deps.find('/Script/UMG.Button'),map)
 self.moreLabel=deps.construct(deps.find('/Script/UMG.TextBlock'),map);self.more:AddChild(self.moreLabel);self.root:AddChild(self.more)
 self.moreLabel:SetVisibility(3);self.moreLabel:SetText(deps.text('展开详情'))
 if deps.theme then deps.theme:button(self.more);deps.theme:text(self.moreLabel,14)end
 self.scroll=deps.construct(deps.find('/Script/UMG.ScrollBox'),map)
 self.detailsBox=deps.construct(deps.find('/Script/UMG.SizeBox'),map)
 self.detailsLabel=deps.construct(deps.find('/Script/UMG.TextBlock'),map)
 self.detailsLabel:SetAutoWrapText(true);self.detailsLabel:SetVisibility(3)
 if deps.theme then deps.theme:text(self.detailsLabel,16)else local detailFont=self.detailsLabel.Font;detailFont.Size=16;self.detailsLabel:SetFont(detailFont)end
 self.scroll:AddChild(self.detailsLabel);self.detailsBox:AddChild(self.scroll);self.root:AddChild(self.detailsBox);self.detailsBox:SetVisibility(1)
 map.MapClickSurface:GetParent():AddChild(self.border)
 self.receiver=deps.construct(deps.find('/Script/UMG.Button'),map);self.receiver:SetVisibility(1);map.MapClickSurface:GetParent():AddChild(self.receiver)
 self.unbind=events:bindClick(self.more,self.receiver,function()self:toggleDetails()end)
 self.slot=deps.layout():SlotAsCanvasSlot(self.border);self.slot:SetZOrder(95)
 self:layout()
 end)
 if not ok then self:clear();error(message)end
 return self
end
function Panel:layout()
 assert(self.slot:IsValid()and self.label:IsValid()and self.detailsLabel:IsValid(),'acquisition panel canvas slot unavailable')
 local layout=self.deps.layout();local pixels=layout:GetViewportSize(self.map);local px,py=pixels.X,pixels.Y
 local dpi=layout:GetViewportScale(self.map)
 assert(type(dpi)=='number' and dpi>0,'viewport DPI unavailable')
 local width,height=px/dpi,py/dpi
 if width~=self.width or height~=self.height then self.layoutPasses=2 end
 if (self.layoutPasses or 0)==0 then return end
 self.layoutPasses=math.max(0,self.layoutPasses-1)
 self.width=width;self.height=height
 self.slot:SetPosition({X=32,Y=math.min(180,height*0.22)})
 self.label:ForceLayoutPrepass()
 local desired=self.label:GetDesiredSize()
 local total=math.max(40,desired.Y)+24+(self.detail and 28 or 0)
 if self.expanded then
  self.detailsLabel:ForceLayoutPrepass()
  local detailHeight=math.max(40,math.min(self.detailsLabel:GetDesiredSize().Y,height*0.58-total))
  self.detailsBox:SetHeightOverride(detailHeight);total=total+detailHeight
 end
 local panelWidth,panelHeight=math.min(440,width*0.34),math.min(total,height*0.58)
 self.slot:SetSize({X=panelWidth,Y=panelHeight})
 self.bounds={x=32,y=math.min(180,height*0.22),width=panelWidth,height=panelHeight}
end
function Panel:set(text,detail)
 assert(self.label:IsValid()and self.detailsLabel:IsValid()and self.more:IsValid()and self.moreLabel:IsValid(),'acquisition panel widgets unavailable')
 self.detail=detail;self.expanded=false
 self.layoutPasses=2
 self.label:SetText(self.deps.text(text));self.border:SetVisibility(4)
 self.detailsLabel:SetText(self.deps.text(detail or''));self.detailsBox:SetVisibility(1)
 self.more:SetVisibility(detail and 0 or 1);self.moreLabel:SetText(self.deps.text('展开详情'))
 self.scroll:ScrollToStart()
 self:layout()
end
function Panel:toggleDetails()
 if not self.detail then return end
 self.expanded=not self.expanded
 self.layoutPasses=2
 self.detailsBox:SetVisibility(self.expanded and 0 or 1)
 self.moreLabel:SetText(self.deps.text(self.expanded and'收起详情'or'展开详情'))
 self:layout()
end
function Panel:updateDetail(detail)
 assert(self.detailsLabel:IsValid()and self.more:IsValid()and self.moreLabel:IsValid(),'acquisition detail widgets unavailable')
 self.detail=detail;self.expanded=self.expanded and detail~=nil;self.layoutPasses=2
 self.detailsLabel:SetText(self.deps.text(detail or''))
 self.detailsBox:SetVisibility(self.expanded and 0 or 1)
 self.more:SetVisibility(detail and 0 or 1)
 self.moreLabel:SetText(self.deps.text(self.expanded and'收起详情'or'展开详情'))
 self:layout()
end
function Panel:isInteracting()return self.border:IsValid()and self.border:IsHovered()end
function Panel:hide()
 self.border:SetVisibility(1)
end
function Panel:clear()
 if self.unbind then self.unbind();self.unbind=nil end
 if self.receiver and self.receiver:IsValid()then self.receiver:RemoveFromParent()end
 if self.border and self.border:IsValid()then self.border:RemoveFromParent()end
end
return Panel
