-- One finite view request, driven by the existing map loop.
local Navigation={};Navigation.__index=Navigation
function Navigation.new(deps)return setmetatable({deps=deps,status='idle'},Navigation)end
function Navigation:cancel()self.pending=nil;self.status='cancelled'end
function Navigation:request(plan)
 self.pending=nil
 if plan.unlocked==false then self.status='locked'
 elseif plan.unlocked~=true then self.status='unknown'
 elseif plan.same_region then self.status='current'
 else
  self.pending={identity=plan.identity,target=plan.target,origin_region=plan.origin_region,origin_big=plan.origin_big};self.status='pending'
 end
 return self.status
end
function Navigation:step()
 local pending=self.pending;if not pending then return end
 local view=self.deps.read()
 if not view or view.identity~=pending.identity then self:cancel();return end
 if pending.origin_region and view.region~=pending.origin_region then self:cancel();return end
 if pending.origin_big~=nil and view.big~=pending.origin_big then self:cancel();return end
 local ok=self.deps.enter(pending.target)
 self.status=ok and'shown'or'unavailable';self.pending=nil
end
return Navigation
