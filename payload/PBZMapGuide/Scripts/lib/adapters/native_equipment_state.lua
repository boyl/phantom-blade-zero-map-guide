-- Current native equipped/soul state only. Never changes equipment or upgrades.
local State={}
local function getter(deps,name,expected)
 local f=deps.find('/Script/ProjectPBZ.PBZBackPackSubsystem:'..name)
 assert(f and f:IsValid(),'native equipment getter unavailable')
 local flags=f:GetFunctionFlags()
 assert((flags&0x400)~=0 and(flags&0x40000000)~=0 and(flags&0x2000)==0,'native equipment getter contract changed')
 local count=0
 f:ForEachProperty(function(p)
  local key=p:GetFName():ToString();local kind=expected[key]
  assert(kind and p:GetFullName():match('^'..kind..' '),'native equipment getter signature changed')
  expected[key]=nil;count=count+1
 end)
 assert(count==3 and next(expected)==nil,'native equipment getter signature incomplete')
 return f
end
function State.read(config,deps)
 if type(config.main)~='boolean'or type(config.extra_rule)~='boolean'or type(config.id)~='string'or config.id==''or config.id=='None'then return{status='unavailable'}end
 local ok,result=pcall(function()
  local equipped=getter(deps,'IsEquipWeaponsByID',{bIsMainWeapon='BoolProperty',ItemId='NameProperty',ReturnValue='BoolProperty'})
  local manager=deps.manager();assert(manager and manager:IsValid(),'native backpack unavailable')
  local value=equipped(manager,config.main,deps.name(config.id))
  assert(type(value)=='boolean','native equipped state must be boolean')
  local result={status='read',equipped=value,soul_status='not_required'}
  if config.extra_rule then
   local success,soul=pcall(function()
    local f=getter(deps,'IsWeaponSnapSouled',{WeaponID='NameProperty',IsNormalWeapon='BoolProperty',ReturnValue='BoolProperty'})
    local value=f(manager,deps.name(config.id),config.main)
    assert(type(value)=='boolean','native soul state must be boolean');return value
   end)
   result.soul_status=success and'read'or'unavailable'
   if success then result.soul=soul else result.soul_reason=tostring(soul)end
  end
  return result
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
return State
