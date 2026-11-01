local Position={};Position.__index=Position
local function ratio(value)return type(value)=='number'and value==value and value>=0 and value<=1 end
function Position.new(saved)
 return setmetatable({saved=saved and ratio(saved.x)and ratio(saved.y)and{x=saved.x,y=saved.y}or nil,down=false},Position)
end
local function range(size,extent)return 16,math.max(16,size-extent-16)end
local function clamp(value,low,high)return math.max(low,math.min(high,value))end
function Position:resolve(bounds,viewport)
 local left,right=range(viewport.width,bounds.width);local top,bottom=range(viewport.height,bounds.height)
 local x=self.saved and left+self.saved.x*(right-left)or bounds.x
 local y=self.saved and top+self.saved.y*(bottom-top)or bounds.y
 return clamp(x,left,right),clamp(y,top,bottom)
end
function Position:reset()self.saved=nil;self.drag=nil end
function Position:update(pointer,bounds,viewport)
 local x,y=self:resolve(bounds,viewport);local committed=false
 local down=pointer and pointer.down==true
 if down and not self.down and pointer.overHandle and type(pointer.x)=='number'and type(pointer.y)=='number'then
  self.drag={x=pointer.x-x,y=pointer.y-y}
 end
 if self.drag and down and type(pointer.x)=='number'and type(pointer.y)=='number'then
  local left,right=range(viewport.width,bounds.width);local top,bottom=range(viewport.height,bounds.height)
  x=clamp(pointer.x-self.drag.x,left,right);y=clamp(pointer.y-self.drag.y,top,bottom)
  self.saved={x=right>left and(x-left)/(right-left)or 0,y=bottom>top and(y-top)/(bottom-top)or 0}
 elseif self.drag and not down then self.drag=nil;committed=true end
 self.down=down
 return{x=x,y=y,dragging=self.drag~=nil,committed=committed,saved=self.saved}
end
return Position
