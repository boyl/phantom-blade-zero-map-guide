local function create(t)
 t=t or function(value)return value end
local View={};View.__index=View
local categories={{'全部类别',false},{'影之武装','phantom_edge'},{'武器','weapon'},{'配饰','accessory'},{'药品','medicine'},{'钥匙与任务道具','key'},{'普通道具','item'},{'记忆之花','memory_flower'},{'黑石碎片','blackstone'},{'琥珀碎片','amber'},{'榕树挑战','banyan'},{'龙柱挑战','dragon_pillar'},{'稻草人挑战','scarecrow'}}
local progress={{'全部进度',false},{'未获取','missing'},{'已获取','collected'},{'状态未知','unknown'},{'当前可获取','available'}}
local states={collected='已获取',missing='未获取',unknown='未知'}
function View.new(deps,map,events,model,geometry,loadRows,select)
 local self=setmetatable({deps=deps,map=map,events=events,model=model,geometry=geometry,loadRows=loadRows,loader=type(loadRows)=='table'and loadRows or nil,select=select,controls={},rows={},page=1,open=false},View)
 local ok,message=pcall(function()
 self.parent=map.MapClickSurface:GetParent()
 self.border=deps.construct(deps.find('/Script/UMG.Border'),map)
 self.border:SetBrushColor(deps.theme and deps.theme.colors.panel or{R=0.015,G=0.025,B=0.03,A=0.96});self.border:SetPadding({Left=0,Right=0,Top=0,Bottom=0});self.border:SetVisibility(1)
 self.root=deps.construct(deps.find('/Script/UMG.CanvasPanel'),map);self.border:AddChild(self.root);self.parent:AddChild(self.border)
 self.borderSlot=deps.layout():SlotAsCanvasSlot(self.border);self.borderSlot:SetZOrder(110)
 self.toggle,self.toggleLabel,self.toggleSlot=self:button(self.parent,t('收集清单'),function()self:setOpen(not self.open)end,self.controls)
 self.toggleSlot:SetZOrder(111)
 self.dragHandle=deps.construct(deps.find('/Script/UMG.Border'),map);self.dragHandle:SetBrushColor({R=0,G=0,B=0,A=0});self.root:AddChild(self.dragHandle)
 if deps.positionModel then self.position=deps.positionModel.new(deps.preferences and deps.preferences.load())end
 self.title=self:label(t('收集清单'),self.root,22,nil,true)
 self.scope=self:label(t('本周目'),self.root,14,deps.theme and deps.theme.colors.muted)
 self.resetButton,self.resetLabel=self:button(self.root,t('复位'),function()
  if self.position then self.position:reset();self:savePosition(nil);self:updatePosition()end
 end,self.controls)
 self.rule=deps.construct(deps.find('/Script/UMG.Border'),map);self.rule:SetBrushColor(deps.theme and deps.theme.colors.line or{R=0.3,G=0.25,B=0.16,A=0.7});self.rule:SetVisibility(3);self.root:AddChild(self.rule)
 self.search=deps.construct(deps.find('/Script/UMG.EditableTextBox'),map);if deps.theme then deps.theme:edit(self.search)end;self.search:SetHintText(deps.text(t('名称 / 拼音 / 首字母 / 地区')));self.root:AddChild(self.search)
 self.category,self.categoryValues=self:combo(categories)
 self.progress,self.progressValues=self:combo(progress)
 self.region,self.regionValues=self:combo({{'全部地区',false}})
 self.summary=self:label('',self.root,14,deps.theme and deps.theme.colors.muted)
 self.summary:SetAutoWrapText(false)
 local viewport=deps.layout():GetViewportSize(map)
 self.summary:SetWrapTextAt(math.min(480,viewport.X/deps.layout():GetViewportScale(map)-48)-28)
 self.previous,_,self.previousSlot=self:button(self.root,t('上一页'),function()self.page=self.page-1;self:render()end,self.controls)
 self.next,_,self.nextSlot=self:button(self.root,t('下一页'),function()self.page=self.page+1;self:render()end,self.controls)
 self.pageLabel=self:label('',self.root,16,deps.theme and deps.theme.colors.muted)
 self.measure=deps.construct(deps.find('/Script/UMG.VerticalBox'),map);self.root:AddChild(self.measure)
 self:label(t('收集品名称'),self.measure,18);self:label(t('地区 · 未获取'),self.measure,14)
 self.measure:SetVisibility(3);self.measure:ForceLayoutPrepass()
 self.rowHeight=math.max(56,self.measure:GetDesiredSize().Y+14);self.measure:SetVisibility(1)
 local function height(widget,minimum)
  widget:ForceLayoutPrepass();return math.max(minimum,widget:GetDesiredSize().Y+4)
 end
 self.summary:SetText(deps.text(t('530 处 · 未获取 429 · 已获取 101 · 未知 0')))
 self.headerMetrics={title=height(self.title,38),search=height(self.search,38),
  combo=math.max(height(self.category,36),height(self.progress,36),height(self.region,36)),summary=height(self.summary,24)}
 self.summary:SetText(deps.text(''))
 self:layout()
 end)
 if not ok then self:clear();error(message)end
 return self
end
function View:place(widget,x,y,w,h)
 local slot=self.deps.layout():SlotAsCanvasSlot(widget);slot:SetPosition({X=x,Y=y});slot:SetSize({X=w,Y=h});return slot
end
function View:label(text,parent,size,color,title)
 local label=self.deps.construct(self.deps.find('/Script/UMG.TextBlock'),self.map)
 local font=label.Font;font.Size=size or 18;label:SetFont(font);label:SetText(self.deps.text(text))
 if self.deps.theme then self.deps.theme:text(label,size or 18,color,title);label:SetTextOverflowPolicy(self.deps.theme.ellipsis)
 else label:SetColorAndOpacity({SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0})end
 label:SetVisibility(3);parent:AddChild(label);return label
end
function View:button(parent,text,callback,owned)
 local button=self.deps.construct(self.deps.find('/Script/UMG.Button'),self.map)
 if self.deps.theme then self.deps.theme:button(button)end
 local label;if text~=nil then label=self:label(text,button,16)end;parent:AddChild(button)
 local receiver=self.deps.construct(self.deps.find('/Script/UMG.Button'),self.map);receiver:SetVisibility(1);self.root:AddChild(receiver)
 local entry={widget=button,receiver=receiver,unbind=self.events:bindClick(button,receiver,callback)};owned[#owned+1]=entry
 return button,label,self.deps.layout():SlotAsCanvasSlot(button)
end
function View:combo(options)
 local combo=self.deps.construct(self.deps.find('/Script/UMG.ComboBoxString'),self.map);local values={}
 if self.deps.theme then self.deps.theme:combo(combo)end
 for _,option in ipairs(options)do combo:AddOption(t(option[1]));values[t(option[1])]=option[2]end
 combo:SetSelectedOption(t(options[1][1]));self.root:AddChild(combo);return combo,values
end
function View:dispose(entries)
 for _,entry in ipairs(entries)do entry.unbind();if entry.widget:IsValid()then entry.widget:RemoveFromParent()end;if entry.receiver:IsValid()then entry.receiver:RemoveFromParent()end end
end
function View:setOpen(open)
 self.open=open;self.border:SetVisibility(open and 4 or 1)
 self.toggleLabel:SetText(self.deps.text(open and t('收起')or t('收集清单')))
 self:updatePosition()
 if open then
  self.lastFilter=nil
  if self.loader then
   self.loader:request();self.all=nil;self.loadingVersion=self.loader.version;self.loadingMessage=nil
   self:dispose(self.rows);self.rows={};self.summary:SetText(self.deps.text(t('正在准备清单…')));self.pageLabel:SetText(self.deps.text('…'))
  else self:acceptRows(self.loadRows())end
 elseif self.loader then self.loader:cancel()
 end
end
function View:acceptRows(rows)
 self.all=rows
 local previous=self.region:GetSelectedOption():ToString()
 local seen={};self.region:ClearOptions();self.region:AddOption(t('全部地区'));self.regionValues={}
 for _,row in ipairs(rows)do
  local region=row.info.regions[1]or row.record.map_id
  if not seen[region]then seen[region]=true;self.region:AddOption(region);self.regionValues[region]={}end
  self.regionValues[region][self.deps.fold(row.record.map_id)]=true
 end
 self.region:SetSelectedOption(seen[previous]and previous or t('全部地区'));self:render()
end
function View:filter()
 local query=self.search:GetText():ToString()
 local category=self.category:GetSelectedOption():ToString();local progressValue=self.progress:GetSelectedOption():ToString();local region=self.region:GetSelectedOption():ToString()
 return{query=query,category=self.categoryValues[category],progress=self.progressValues[progressValue],map_ids=self.regionValues[region]},table.concat({query,category,progressValue,region},'\n')
end
function View:render()
 if not self.open or not self.all then return end
 if self.deps.report then self.deps.report('Collection render begin')end
 self:dispose(self.rows);self.rows={}
 local filter,key=self:filter();self.lastFilter=key
 local selected=self.model.select(self.all,filter,self.deps.fold,self.deps.phonetic);local page=self.model.page(selected,self.page,self.bounds.capacity);self.page=page.page
 local counts=self.model.counts(selected)
 self.summary:SetText(self.deps.text(string.format(t('%d 处 · 未获取 %d · 已获取 %d · 未知 %d'),counts.total,counts.missing,counts.collected,counts.unknown)))
 self.pageLabel:SetText(self.deps.text(page.page..' / '..page.pages))
 for index,row in ipairs(page.rows)do
  local button=self:button(self.root,nil,function()self:setOpen(false);self.select(row.info,row.record)end,self.rows)
  local content=self.deps.construct(self.deps.find('/Script/UMG.VerticalBox'),self.map);local slot=button:AddChild(content)
  if self.deps.theme then slot:SetHorizontalAlignment(self.deps.theme.fill);slot:SetVerticalAlignment(self.deps.theme.center)end
  local color=self.deps.theme and(row.completion=='collected' and self.deps.theme.colors.muted or self.deps.theme.colors.text)
  local title=self:label(row.info.title,content,18,color)
  if self.deps.theme then title:SetToolTipText(self.deps.text(row.info.title))end
  self:label((row.info.regions[1]or row.record.map_id)..' · '..t(states[row.completion]),content,14,self.deps.theme and self.deps.theme.colors.muted)
  self:place(button,12,self.bounds.rowStart+(index-1)*self.bounds.rowHeight,self.bounds.width-24,self.bounds.rowHeight-4)
 end
 if self.deps.report then self.deps.report('Collection render ready rows='..#page.rows)end
end
function View:layout()
 local pixels=self.deps.layout():GetViewportSize(self.map);local px,py=pixels.X,pixels.Y
 local dpi=self.deps.layout():GetViewportScale(self.map)
 local width,height=px/dpi,py/dpi
 if width==self.width and height==self.height then return end
 self.summary:SetWrapTextAt(math.min(480,width-48)-28);self.summary:ForceLayoutPrepass()
 self.headerMetrics.summary=math.max(self.headerMetrics.summary,self.summary:GetDesiredSize().Y+4)
 self.width=width;self.height=height;self.bounds=self.geometry.calculate(width,height,self.rowHeight,self.headerMetrics,self.deps.guideBounds and self.deps.guideBounds())
 local b=self.bounds;self.borderSlot:SetPosition({X=b.x,Y=b.y});self.borderSlot:SetSize({X=b.width,Y=b.height})
 self:place(self.dragHandle,0,0,b.width,b.ruleY)
 self:place(self.title,16,10,b.width-272,b.titleHeight);self:place(self.scope,b.width-256,20,84,b.summaryHeight)
 self:place(self.resetButton,b.width-88,12,72,math.max(34,b.titleHeight))
 self:place(self.rule,16,b.ruleY,b.width-32,1)
 self:place(self.search,12,b.searchY,b.width-24,b.searchHeight)
 self:place(self.category,12,b.categoryY,(b.width-30)/2,b.comboHeight);self:place(self.progress,18+(b.width-30)/2,b.categoryY,(b.width-30)/2,b.comboHeight)
 self:place(self.region,12,b.regionY,b.width-24,b.comboHeight);self:place(self.summary,14,b.summaryY,b.width-28,b.summaryHeight)
 self.previousSlot:SetPosition({X=12,Y=b.footerY});self.previousSlot:SetSize({X=120,Y=36})
 self.nextSlot:SetPosition({X=b.width-132,Y=b.footerY});self.nextSlot:SetSize({X=120,Y=36})
 self:place(self.pageLabel,145,b.footerY+4,b.width-290,30);self:updatePosition();self:render()
end
function View:savePosition(position)
 if self.deps.preferences then
  local ok,message=self.deps.preferences.save(position)
  if not ok then print('[PBZMapGuide] Panel preference unavailable: '..tostring(message)..'\n')end
 end
end
function View:updatePosition()
 local result={x=self.bounds.x,y=self.bounds.y}
 if self.position then
  local pointer={down=false}
  if self.open and self.deps.pointer then
   local over=self.dragHandle:IsHovered()
   pointer=self.deps.pointer(self.map,over or self.dragActive);pointer.overHandle=over
  end
  result=self.position:update(pointer,self.bounds,{width=self.width,height=self.height})
  self.dragActive=result.dragging
  if result.committed then self:savePosition(result.saved)end
 end
 self.borderSlot:SetPosition({X=result.x,Y=result.y})
 self.toggleSlot:SetPosition({X=result.x+(self.open and self.bounds.width-168 or 0),Y=result.y+(self.open and 12 or 0)})
 self.toggleSlot:SetSize({X=self.open and 72 or 180,Y=self.open and math.max(34,self.bounds.titleHeight)or 40})
end
function View:update()
 if self.loader then
  self.loader:step()
  if self.open then
   if self.loader.version~=self.loadingVersion then
    self.loadingVersion=self.loader.version
    if self.loader.rows then self:acceptRows(self.loader.rows)
    else self.summary:SetText(self.deps.text(t('清单暂不可用')))end
   elseif not self.all then
    local message=self.loader.status=='unavailable'and t('清单暂不可用')or(self.loader.status=='preparing'and string.format(t('正在准备清单 %d / %d'),self.loader.processed,self.loader.total)or t('正在读取当前进度…'))
    if message~=self.loadingMessage then self.loadingMessage=message;self.summary:SetText(self.deps.text(message))end
   end
  end
 end
 self:layout();self:updatePosition();if not self.open then return end
 local _,key=self:filter();if key~=self.lastFilter then self.page=1;self:render()end
end
function View:clear()
 if self.loader then self.loader:stop()end
 self:dispose(self.rows);self.rows={};self:dispose(self.controls);self.controls={}
 if self.border and self.border:IsValid()then self.border:RemoveFromParent()end
end
View.withTranslator=create
return View
end
return create()
