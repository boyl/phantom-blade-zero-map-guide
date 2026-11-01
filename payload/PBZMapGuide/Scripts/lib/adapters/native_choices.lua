-- Copy raw native dialogue configuration; output binding and tag logic are separate.
local Choices={}
local required={FlowLocText='StructProperty',FilterTags='StructProperty',HiddenTags='StructProperty',ListenQuest='ArrayProperty',ExactMatchListenQuest='BoolProperty',FilterType='ByteProperty'}
local function fields(node)
 local property
 node:GetClass():ForEachProperty(function(value)
  if value:GetFName():ToString()=='ChoiceData'then assert(not property,'ambiguous native ChoiceData');property=value end
 end)
 assert(property,'native ChoiceData unavailable')
 local shape=property:GetInner():GetStruct()
 assert(shape:GetFullName():match('/Struct/BT_FlowChoiceContentData%.BT_FlowChoiceContentData$'),'unsupported native choice content type')
 local result={}
 shape:ForEachProperty(function(value)
  local name=value:GetFName():ToString();local base,suffix=name:match('^([%a]+)_%d+_(%x+)$')
  if base and #suffix==32 and required[base]then
   assert(not result[base],'ambiguous native choice field: '..base)
   assert(value:GetFullName():match('^'..required[base]..' '),'unexpected native choice field type: '..base)
   result[base]=name
  end
 end)
 for key in pairs(required)do assert(result[key],'native choice field missing: '..key)end
 return result
end
function Choices.read(node,deps)
 local keys=fields(node);local values=node.ChoiceData
 assert(#values<=64,'unsupported native choice count')
 local result={}
 values:ForEach(function(_,param)
  local value=param:get();local text=value[keys.FlowLocText]
  local filterType=value[keys.FilterType];local exact=value[keys.ExactMatchListenQuest]
  assert(type(filterType)=='number'and filterType%1==0 and filterType>=0 and filterType<=255,'invalid native choice filter enum')
  assert(type(exact)=='boolean','invalid native quest matching flag')
  result[#result+1]={index=#result,text={namespace=text.Namespace:ToString(),key=text.Key:ToString(),cache=text.ValueCache:ToString()},
   filter_tags=deps.tags(value[keys.FilterTags]),hidden_tags=deps.tags(value[keys.HiddenTags]),
   listen_quests=deps.quests(value[keys.ListenQuest]),exact_quest=exact,filter_type=filterType}
 end)
 return result
end
function Choices.filterLabel(value,deps)
 assert(type(value)=='number'and value%1==0,'invalid native filter value')
 local enum=deps.find('/Game/PBZContent/Blueprint/StateTree/Enum/E_TagFilterType.E_TagFilterType')
 if not enum or not enum:IsValid()then return nil end
 local key=enum:GetNameByValue(value):ToString():match('([^:]+)$')
 if not key or key=='None'then return nil end
 local values=enum.DisplayNameMap;assert(#values<=64,'unsupported native filter display map')
 local label
 values:ForEach(function(name,text)
  if name:get():ToString():match('([^:]+)$')==key then
   assert(label==nil,'ambiguous native filter display label');label=text:get():ToString()
  end
 end)
 return label~=''and label or nil
end
return Choices
