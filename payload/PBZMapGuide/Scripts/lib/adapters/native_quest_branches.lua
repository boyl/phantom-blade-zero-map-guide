-- Preserve raw allow/deny quest groups. No node execution or false-branch inversion.
local Branches={}
local function keys(shape,required)
 local result={}
 shape:ForEachProperty(function(p)
  local name=p:GetFName():ToString();local base,hash=name:match('^([%a]+)_%d+_(%x+)$')
  if base and #hash==32 and required[base]then
   assert(not result[base]and p:GetFullName():match('^'..required[base]..' '),'unsupported native quest group field')
   result[base]={name=name,property=p}
  end
 end)
 for name in pairs(required)do assert(result[name],'native quest group field missing')end
 return result
end
local function entries(property)
 local shape=property:GetInner():GetStruct()
 assert(shape:GetFullName():match('/FlowGraph/Struct/QuestConditionState%.QuestConditionState$'),'unsupported native quest state structure')
 local fields=keys(shape,{Quest='ClassProperty',BranchID='NameProperty',State='EnumProperty'})
 assert(fields.State.property:GetEnum():GetFullName()=='Enum /Script/ProjectPBZ.EPBZQuestBranchState','unsupported native grouped quest-state enum')
 return fields
end
local function read(values,fields)
 assert(#values<=64,'native quest group entry bound');local result={}
 values:ForEach(function(_,parameter)
  local value=parameter:get();local quest=value[fields.Quest.name]
  assert(quest:IsValid(),'native grouped quest class unavailable')
  local state=value[fields.State.name]
  assert(type(state)=='number'and state%1==0 and state>=0 and state<=255,'invalid native grouped quest state')
  result[#result+1]={quest=quest:GetFullName(),branch=value[fields.BranchID.name]:ToString(),state=state}
 end)
 return result
end
function Branches.read(node)
 assert(type(node.ConditionsAnd)=='boolean','invalid native quest combination flag')
 local property
 node:GetClass():ForEachProperty(function(p)if p:GetFName():ToString()=='Conditions'then assert(not property,'ambiguous native quest groups');property=p end end)
 assert(property and property:GetFullName():match('^ArrayProperty '),'native quest groups array unavailable')
 local shape=property:GetInner():GetStruct()
 assert(shape:GetFullName():match('/FlowGraph/Struct/QuestCondition%.QuestCondition$'),'unsupported native quest group structure')
 local fields=keys(shape,{Allow='ArrayProperty',Deny='ArrayProperty'})
 local allow,deny=entries(fields.Allow.property),entries(fields.Deny.property)
 local values=node.Conditions;assert(#values<=64,'native quest branch group bound')
 local result={conditions_and=node.ConditionsAnd,groups={}}
 values:ForEach(function(_,parameter)
  local value=parameter:get()
  result.groups[#result.groups+1]={allow=read(value[fields.Allow.name],allow),deny=read(value[fields.Deny.name],deny)}
 end)
 return result
end
return Branches
