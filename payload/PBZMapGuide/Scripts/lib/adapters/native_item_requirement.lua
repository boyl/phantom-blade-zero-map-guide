-- Current material sufficiency only. Never represents collection history.
local Requirement={}
function Requirement.read(id,count,deps)
 if type(id)~='string'or id==''or id=='None'or type(count)~='number'or count%1~=0 or count<=0 or count>2147483647 then return{status='unavailable'}end
 local ok,result=pcall(function()
  local f=deps.find('/Script/ProjectPBZ.PBZBackPackSubsystem:HasEnoughItem')
  assert(f and f:IsValid(),'native item requirement query unavailable')
  local flags=f:GetFunctionFlags()
  assert((flags&0x400)~=0 and(flags&0x40000000)~=0 and(flags&0x2000)==0,'native item requirement getter contract changed')
  local metadata,overflow={},false
  f:ForEachProperty(function(p)
   if #metadata>=8 then overflow=true;return end
   metadata[#metadata+1]={name=p:GetFName():ToString(),kind=p:GetFullName():match('^(%S+) ')}
  end)
  assert(not overflow,'native item predicate parameter bound')
  local expected={{'ItemId','NameProperty'},{'Num','IntProperty'},{'RequireNum','IntProperty'},{'ReturnValue','BoolProperty'}}
  assert(#metadata==#expected,'native item predicate signature incomplete')
  for i,field in ipairs(metadata)do
   assert(field.name==expected[i][1]and field.kind==expected[i][2],'native item predicate parameter contract changed')
  end
  local manager=deps.manager();assert(manager and manager:IsValid(),'native backpack unavailable')
  -- Actual native signature has a trailing integer out parameter. Do not infer its meaning.
  local output={}
  local enough=f(manager,deps.name(id),count,output)
  assert(type(enough)=='boolean','native item sufficiency must be boolean')
  return{status='read',enough=enough}
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
return Requirement
