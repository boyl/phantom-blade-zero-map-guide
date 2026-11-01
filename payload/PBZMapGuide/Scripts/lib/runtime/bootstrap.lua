-- Start only after a real map exists. All engine access stays in the game-thread queue.
local Bootstrap={}
function Bootstrap.start(root,deps)
 local state={active=true,attempts=0,prepared=false,phase='scheduled'}
 function state.stop()
  if not state.active then return end;state.active=false;state.phase='stopped'
  deps.queue(function()if state.instance then state.instance.stop();state.instance=nil end end)
 end
 local function poll()
  if not state.active then return end
  deps.queue(function()
   if not state.active then return end
   local ok,message=pcall(function()
    if not state.prepared then state.phase='preparing';deps.log('Preparing native map access');deps.prepare();state.prepared=true end
    if not deps.ready()then
     if state.phase~='waiting' then deps.log('Waiting for an active native map');state.phase='waiting'end
     return
    end
    state.phase='starting';deps.log('Native map ready; starting runtime')
    local runtime=deps.load();state.instance=runtime.start(root,deps.options)
    state.phase='running'
   end)
   if not ok then
    state.attempts=state.attempts+1;deps.log('Startup unavailable: '..tostring(message))
    if state.attempts>=3 then state.active=false;state.phase='failed';deps.log('Startup disabled after bounded failures; native map retained');return end
   end
   if state.active and not state.instance then deps.delay(1000,poll)end
  end)
 end
 deps.log('Entry loaded; startup deferred until loader initialization completes')
 deps.delay(1000,poll);return state
end
return Bootstrap
