-- Read an exact existing quest branch. Never starts a quest or executes a flow node.
local State={}
local function metadata(deps,path,purityFlag)
 local f=deps.find(path);assert(f and f:IsValid(),'native quest state getter unavailable')
 local flags=f:GetFunctionFlags()
 assert((flags&0x400)~=0 and(flags&(purityFlag or 0x40000000))~=0 and(flags&0x2000)==0,'native quest state getter contract changed')
 local fields,overflow={},false
 f:ForEachProperty(function(p)
  if #fields>=8 then overflow=true;return end
  fields[#fields+1]={name=p:GetFName():ToString(),kind=p:GetFullName():match('^(%S+) '),property=p}
 end)
 assert(not overflow,'native quest state metadata bound');return f,fields
end
function State.read(quest,condition,deps)
 if condition.group then return{status='unsupported_group'}end
 if type(condition.branch)~='string'or condition.branch==''or condition.branch=='None'then return{status='unavailable'}end
 local ok,result=pcall(function()
  assert(quest and quest:IsValid()and quest:GetClass():GetFullName()==condition.quest,'native quest identity unavailable')
  local getBranch,fields=metadata(deps,'/Script/Narrative.Quest:GetBranch')
  local input,output=0,0
  for _,field in ipairs(fields)do
   if field.name=='ReturnValue'then assert(field.kind=='ObjectProperty','native branch return type changed');output=output+1
   else assert(field.kind=='NameProperty','native branch input changed');input=input+1 end
  end
  assert(input==1 and output==1,'native branch signature changed')
  local getState,states=metadata(deps,'/Script/ProjectPBZ.PBZQuestBranch:GetBranchState',0x10000000)
  assert(#states==1 and states[1].name=='ReturnValue'and(states[1].kind=='EnumProperty'or states[1].kind=='ByteProperty'),'native branch state signature changed')
  assert(states[1].property:GetEnum():GetFullName()=='Enum /Script/ProjectPBZ.EPBZQuestBranchState','native branch state enum changed')
  local branch=getBranch(quest,deps.name(condition.branch))
  if not branch or not branch:IsValid()then return{status='branch_unavailable'}end
  local cls=deps.find('/Script/ProjectPBZ.PBZQuestBranch')
  assert(cls and cls:IsValid()and branch:IsA(cls),'unsupported native quest branch class')
  local value=getState(branch)
  assert(type(value)=='number'and value%1==0 and value>=0 and value<=255,'invalid native branch state')
  return{status='read',state=value}
 end)
 if ok then return result end
 return{status='unavailable',reason=tostring(result)}
end
return State
