-- The existing game-thread map loop calls step(). No independent callbacks are created.
local Discovery={};Discovery.__index=Discovery
function Discovery.new(deps)
 local batch=deps.batch_size or 4
 assert(batch%1==0 and batch>=1 and batch<=8,'unsupported discovery batch size')
 return setmetatable({deps=deps,batch=batch,state={status='idle',version=0,read=0,failed=0,by_tag={},errors={}}},Discovery)
end
function Discovery:stop()
 self.stopped=true
 if self.state.status=='loading'or self.state.status=='idle'then self.state.status='cancelled'end
end
function Discovery:ensure()
 if self.state.status=='idle'and not self.stopped then self.state.status='loading'end
 return self.state
end
function Discovery:step()
 local state=self.state
 if self.stopped or state.status~='loading'then return end
 if not self.paths then
  local ok,index=pcall(self.deps.read_index)
  if not ok or index.status~='read'then
   state.status='unavailable';state.error=ok and(index.reason or'asset registry unavailable')or tostring(index)
   state.version=state.version+1;return
  end
  self.paths={};for i,path in ipairs(index.paths)do self.paths[i]=path end
  state.total=#self.paths;self.next=1
  if state.total==0 then state.status='ready';state.complete=true;state.version=state.version+1;self.paths=nil end
  return
 end
 local last=math.min(#self.paths,self.next+self.batch-1)
 for i=self.next,last do
  local path=self.paths[i];local ok,graph=pcall(self.deps.read_graph,path)
  if ok and graph.status=='read'then
   state.read=state.read+1
   for guid,node in pairs(graph.nodes)do
    if node.kind=='set_tags'and node.signal_mode==0 and not node.use_cache then
     for _,tag in ipairs(node.added_tags)do
      local key=tag:lower();state.by_tag[key]=state.by_tag[key]or{}
      state.by_tag[key][#state.by_tag[key]+1]={path=path,guid=guid,with_source=node.with_source,tag=tag}
     end
    end
   end
  else
   state.failed=state.failed+1
   if #state.errors<20 then state.errors[#state.errors+1]={path=path,reason=ok and(graph.reason or'unsupported template')or tostring(graph)}end
  end
 end
 self.next=last+1;state.processed=last
 if self.next>#self.paths then
  state.status='ready';state.complete=state.failed==0;state.version=state.version+1;self.paths=nil
 end
end
return Discovery
