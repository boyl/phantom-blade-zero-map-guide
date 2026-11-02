-- Primitive metadata persists only for this map UI session; progress is never reused across opens.
local Loader={};Loader.__index=Loader
function Loader.new(deps)
 local batch=deps.batch or 24
 assert(batch>=1 and batch<=64 and batch%1==0,'invalid collection preparation batch')
 return setmetatable({deps=deps,batch=batch,prepared={},processed=0,total=#deps.records,version=0,status='preparing',failed=0},Loader)
end
function Loader:request()
 self.requested=true;self.rows=nil
end
function Loader:cancel()self.requested=false end
function Loader:stop()self:cancel();self.stopped=true end
function Loader:step()
 if self.stopped or self.status=='unavailable'then return end
 local ok,why=pcall(function()
  if self.processed<self.total then
   if self.processed==0 and self.deps.report then self.deps.report('Collection metadata begin')end
   local context=self.deps.context()
   local last=math.min(self.total,self.processed+self.batch)
   for i=self.processed+1,last do
    local success,value=pcall(self.deps.prepare,self.deps.records[i],i,context)
    if success then self.prepared[i]=value
    elseif self.deps.fallback then
     self.prepared[i]=self.deps.fallback(self.deps.records[i],i)
     self.failed=self.failed+1
     if self.deps.report then self.deps.report('Collection record '..i..' unavailable: '..tostring(value))end
    else error(value)end
   end
   self.processed=last
   if last==self.total then
    self.status='ready'
    if self.deps.report then self.deps.report('Collection metadata ready rows='..self.total..' unavailable='..self.failed)end
   end
  else self.status='ready'end
  if self.status=='ready'and self.requested then
   if self.deps.report then self.deps.report('Collection progress begin')end
   local snapshot=self.deps.snapshot()
   self.rows=self.deps.refresh(self.prepared,snapshot)
   self.requested=false;self.version=self.version+1
   if self.deps.report then self.deps.report('Collection progress ready rows='..#self.rows)end
  end
 end)
 if not ok then
  self.status='unavailable';self.error=tostring(why);self.rows=nil;self.requested=false;self.version=self.version+1
  if self.deps.report then self.deps.report('Collection unavailable: '..self.error)end
 end
end
return Loader
