-- Read the text language, never the OS locale or Steam download language.
local Language={}
function Language.read(deps)
 -- The game also ships EasyLocalizationTool. Prefer its text language when its
 -- reflected getter is a native, zero-input string/name getter; never guess ABI.
 local customOk,custom=pcall(function()
  local getter=deps.find('/Script/EasyLocalizationTool.ELTBlueprintLibrary:GetCurrentLanguage')
  assert(getter and getter:IsValid()and(getter:GetFunctionFlags()&0x400)~=0,'game language getter unavailable')
  local count=0
  getter:ForEachProperty(function(p)
   count=count+1
   local kind=p:GetFullName():match('^(%S+) ')
   assert(count==1 and p:GetFName():ToString()=='ReturnValue'and(kind=='StrProperty'or kind=='NameProperty'),'game language getter signature changed')
  end)
  assert(count==1,'game language getter signature incomplete')
  local library=deps.find('/Script/EasyLocalizationTool.Default__ELTBlueprintLibrary')
  assert(library and library:IsValid(),'game language library unavailable')
  local value=library:GetCurrentLanguage()
  return type(value)=='string'and value or value:ToString()
 end)
 if customOk and type(custom)=='string'and custom~=''then return custom end
 local ok,value=pcall(function()
  local library=deps.find('/Script/Engine.Default__KismetInternationalizationLibrary')
  assert(library and library:IsValid(),'language library unavailable')
  local result=library:GetCurrentLanguage()
  return type(result)=='string'and result or result:ToString()
 end)
 if ok and type(value)=='string'and value~=''then return value end
 if deps.report then deps.report('Game text language unavailable; using English')end
 return nil
end
function Language.resolve(text,find)
 local namespace,key=text.Namespace:ToString(),text.Key:ToString()
 if key==''then return nil end
 local out={}
 local found=find('/Script/Engine.Default__KismetTextLibrary'):FindTextInLocalizationTable(namespace,key,out,'')
 if found and out.OutText then
  local value=out.OutText:ToString();if value~=''then return value end
 end
end
return Language
