local Geometry={}
local function finite(value)return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
function Geometry.point(uv,size)
 assert(finite(uv.X) and finite(uv.Y),'native projection must contain finite numbers')
 assert(finite(size.X) and finite(size.Y) and size.X>0 and size.Y>0,'native map canvas has no usable size')
 return {X=uv.X*size.X,Y=uv.Y*size.Y}
end
function Geometry.pan(point,size,viewport)
 assert(finite(viewport.X) and finite(viewport.Y) and viewport.X>0 and viewport.Y>0,'viewport has no usable size')
 return {X=math.max(math.min(0,viewport.X-size.X),math.min(0,viewport.X/2-point.X)),Y=math.max(math.min(0,viewport.Y-size.Y),math.min(0,viewport.Y/2-point.Y))}
end
function Geometry.same(a,b)return math.abs(a.X-b.X)<0.1 and math.abs(a.Y-b.Y)<0.1 end
return Geometry
