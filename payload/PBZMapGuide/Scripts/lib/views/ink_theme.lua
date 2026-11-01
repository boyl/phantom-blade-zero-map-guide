-- Styling uses Mod-owned Slate structs and optional fonts already supplied by the game.
local Theme={};Theme.__index=Theme
local palette={
 panel={R=0.018,G=0.016,B=0.012,A=0.95},surface={R=0.032,G=0.028,B=0.021,A=0.94},
 hover={R=0.105,G=0.079,B=0.043,A=0.98},pressed={R=0.16,G=0.12,B=0.06,A=1},
 text={R=0.84,G=0.80,B=0.69,A=1},muted={R=0.44,G=0.40,B=0.32,A=1},
 accent={R=0.48,G=0.35,B=0.18,A=1},line={R=0.23,G=0.18,B=0.11,A=0.65},
}
function Theme.slate(color)return{SpecifiedColor={R=color.R,G=color.G,B=color.B,A=color.A},ColorUseRule=0}end
local function enum(deps,path,key)
 local value;local object=deps.find(path);assert(object:IsValid(),'theme enum unavailable: '..path)
 object:ForEachName(function(name,number)if name:ToString():match('([^:]+)$')==key then value=number end end)
 assert(value~=nil,'theme enum value unavailable: '..key);return value
end
function Theme.new(deps)
 local self=setmetatable({colors=palette},Theme)
 self.image=enum(deps,'/Script/SlateCore.ESlateBrushDrawType','Image')
 self.fill=enum(deps,'/Script/SlateCore.EHorizontalAlignment','HAlign_Fill')
 self.center=enum(deps,'/Script/SlateCore.EVerticalAlignment','VAlign_Center')
 self.ellipsis=enum(deps,'/Script/SlateCore.ETextOverflowPolicy','Ellipsis')
 local function font(name)
  local object=deps.find('/Game/PBZContent/UI/Fonts/'..name..'.'..name)
  if object:IsValid()then return object end
 end
 if deps.language~='en'then
  self.bodyFont=font('ZH_FZKaiTi_Font');self.titleFont=font('ZH_ZiKuTangKuangShanKaiShuJF_Font')or self.bodyFont
 end
 return self
end
function Theme:font(font,size,title)
 local object=title and self.titleFont or self.bodyFont
 if object then font.FontObject=object end
 font.Size=size
end
function Theme:text(widget,size,color,title)
 local font=widget.Font;self:font(font,size or 18,title);widget:SetFont(font)
 widget:SetColorAndOpacity(Theme.slate(color or palette.text))
end
function Theme:brush(brush,color)
 brush.DrawAs=self.image;brush.TintColor=Theme.slate(color)
end
function Theme:buttonStyle(style)
 self:brush(style.Normal,palette.surface);self:brush(style.Hovered,palette.hover)
 self:brush(style.Pressed,palette.pressed);self:brush(style.Disabled,palette.panel)
 style.NormalForeground=Theme.slate(palette.text);style.HoveredForeground=Theme.slate(palette.text)
 style.PressedForeground=Theme.slate(palette.text);style.DisabledForeground=Theme.slate(palette.muted)
 style.NormalPadding={Left=10,Top=5,Right=10,Bottom=5};style.PressedPadding={Left=10,Top=5,Right=10,Bottom=5}
end
function Theme:button(widget)
 local style=widget.WidgetStyle;self:buttonStyle(style);widget:SetStyle(style)
end
function Theme:scroll(style)
 for _,field in ipairs({'NormalThumbImage','HoveredThumbImage','DraggedThumbImage'})do self:brush(style[field],palette.accent)end
 for _,field in ipairs({'HorizontalBackgroundImage','VerticalBackgroundImage','VerticalTopSlotImage','HorizontalTopSlotImage','VerticalBottomSlotImage','HorizontalBottomSlotImage'})do self:brush(style[field],palette.surface)end
end
function Theme:edit(widget)
 local style=widget.WidgetStyle
 self:brush(style.BackgroundImageNormal,palette.surface);self:brush(style.BackgroundImageHovered,palette.hover)
 self:brush(style.BackgroundImageFocused,palette.hover);self:brush(style.BackgroundImageReadOnly,palette.panel)
 style.ForegroundColor=Theme.slate(palette.text);style.ReadOnlyForegroundColor=Theme.slate(palette.muted)
 style.FocusedForegroundColor=Theme.slate(palette.text);style.BackgroundColor=Theme.slate({R=1,G=1,B=1,A=1})
 style.Padding={Left=12,Top=5,Right=12,Bottom=5}
 self:font(style.Textstyle.Font,16);style.Textstyle.ColorAndOpacity=Theme.slate(palette.text)
 style.Textstyle.SelectedBackgroundColor=Theme.slate(palette.hover);style.Textstyle.HighlightColor=palette.accent
 self:scroll(style.ScrollBarStyle)
end
function Theme:combo(widget)
 local combo=widget.WidgetStyle.ComboButtonStyle
 self:buttonStyle(combo.ButtonStyle);self:brush(combo.MenuBorderBrush,palette.panel);self:brush(combo.DownArrowImage,palette.accent)
 combo.MenuBorderPadding={Left=1,Top=1,Right=1,Bottom=1}
 widget.ForegroundColor=Theme.slate(palette.text);self:font(widget.Font,16)
 widget.ContentPadding={Left=12,Top=5,Right=12,Bottom=5};widget.MaxListHeight=360
 local rows=widget.ItemStyle
 for _,field in ipairs({'SelectorFocusedBrush','ActiveHoveredBrush','ActiveBrush','InactiveHoveredBrush','InactiveBrush','ParentRowBackgroundHoveredBrush','EvenRowBackgroundHoveredBrush','OddRowBackgroundHoveredBrush','ActiveHighlightedBrush','InactiveHighlightedBrush'})do self:brush(rows[field],palette.hover)end
 for _,field in ipairs({'ParentRowBackgroundBrush','EvenRowBackgroundBrush','OddRowBackgroundBrush'})do self:brush(rows[field],palette.surface)end
 rows.TextColor=Theme.slate(palette.text);rows.SelectedTextColor=Theme.slate(palette.text)
 self:scroll(widget.ScrollBarStyle)
end
return Theme
