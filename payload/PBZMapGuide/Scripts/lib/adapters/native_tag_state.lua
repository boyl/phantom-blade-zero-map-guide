-- Query current native tag records only; never execute a flow condition.
local State={}
-- Accept a live native container; never reconstruct its TArray from guessed tag rules.
function State.read_all(container,deps)
 local ok,result=pcall(function()
  local f=deps.find('/Script/ProjectPBZ.EventPipelineManager:HasTagsWithOutSource')
  assert(f and f:IsValid(),'native tag-container query unavailable')
  local flags=f:GetFunctionFlags()
  assert((flags&0x400)~=0 and(flags&0x40000000)~=0 and(flags&0x2000)==0,'native tag-container getter contract changed')
  local fields,overflow={},false
  f:ForEachProperty(function(p)
   if #fields>=8 then overflow=true;return end
   fields[#fields+1]={name=p:GetFName():ToString(),kind=p:GetFullName():match('^(%S+) '),property=p}
  end)
  assert(not overflow and #fields==2,'native tag-container signature changed')
  local input,output=0,0
  for _,field in ipairs(fields)do
   if field.name=='ReturnValue'then assert(field.kind=='BoolProperty','native tag-container return changed');output=output+1
   else
    assert(field.kind=='StructProperty'and field.property:GetStruct():GetFullName()=='ScriptStruct /Script/GameplayTags.GameplayTagContainer','native tag-container input changed')
    input=input+1
   end
  end
  assert(input==1 and output==1,'native tag-container signature incomplete')
  local manager=deps.manager();assert(manager and manager:IsValid(),'native event manager unavailable')
  local value=f(manager,container);assert(type(value)=='boolean','native tag-container result must be boolean')
  return{status='read',present=value}
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
function State.read(tag,scope,deps)
 scope=scope or{}
 if type(tag)~='string'or tag==''or tag=='None'then return{status='unavailable'}end
 if scope.specific and(type(scope.source)~='string'or scope.source==''or scope.source=='None')then return{status='unresolved_source'}end
 local ok,result=pcall(function()
  local path='/Script/ProjectPBZ.EventPipelineManager:'..(scope.specific and'HasTagWithSource'or'HasTagWithOutSource')
  local f=deps.find(path);assert(f and f:IsValid(),'native tag query unavailable')
  local flags=f:GetFunctionFlags();assert((flags&0x400)~=0 and(flags&0x40000000)~=0,'native tag query must remain a const native getter')
  local expected={Tag='StructProperty',ReturnValue='BoolProperty'}
  if scope.specific then expected.SourceSaveGuid='StrProperty'end
  local count=0;local fields={};local overflow=false
  f:ForEachProperty(function(p)
   if #fields>=8 then overflow=true;return end
   fields[#fields+1]={key=p:GetFName():ToString(),full=p:GetFullName(),property=p}
  end)
  assert(not overflow,'native tag query metadata bound')
  for _,p in ipairs(fields)do
   local key=p.key;local kind=expected[key]
   assert(kind and p.full:match('^'..kind..' '),'native tag query signature changed')
   if key=='Tag'then assert(p.property:GetStruct():GetFullName()=='ScriptStruct /Script/GameplayTags.GameplayTag','native tag structure changed')end
   expected[key]=nil;count=count+1
  end
  assert(count==(scope.specific and 3 or 2)and next(expected)==nil,'native tag query signature incomplete')
  local manager=deps.manager();assert(manager and manager:IsValid(),'native event manager unavailable')
  local value
  if scope.specific then value=f(manager,{TagName=deps.name(tag)},scope.source)
  else value=f(manager,{TagName=deps.name(tag)})end
  assert(type(value)=='boolean','native tag record must be boolean')
  return{status='read',present=value}
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
return State
