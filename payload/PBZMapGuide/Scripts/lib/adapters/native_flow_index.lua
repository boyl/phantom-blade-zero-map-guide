-- Asset Registry query only. Run on the game thread; return primitive paths, never engine rows.
local Index={}
function Index.read(deps)
 local helper=deps.find('/Script/AssetRegistry.Default__AssetRegistryHelpers')
 if not helper:IsValid()then return{status='unavailable',reason='asset registry helper unavailable'}end
 local registry=helper:GetAssetRegistry()
 if not registry or not registry:IsValid()then return{status='unavailable',reason='asset registry unavailable'}end
 local out={}
 local found=registry:GetAssetsByClass({PackageName=deps.name('/Script/Flow'),AssetName=deps.name('FlowAsset')},out,true)
 if not found then return{status='unavailable',reason='flow asset registry query failed'}end
 assert(#out<=16384,'unsupported flow asset index size')
 if #out==0 then return{status='unavailable',reason='no flow assets indexed'}end
 local result={status='read',paths={},by_name={}};local seen={}
 for _,parameter in ipairs(out)do
  local row=parameter:get()
  local package=row.PackageName:ToString();local name=row.AssetName:ToString()
  if package:match('^/Game/')then
   assert(name~=''and name~='None','flow asset name unavailable')
   local path=package..'.'..name
   if not seen[path:lower()]then
    seen[path:lower()]=true;result.paths[#result.paths+1]=path
    local key=name:lower();result.by_name[key]=result.by_name[key]or{}
    result.by_name[key][#result.by_name[key]+1]=path
   end
  end
 end
 table.sort(result.paths);return result
end
function Index.resolve(index,name)
 if index.status~='read'then return{status='unavailable'}end
 local values=index.by_name[tostring(name):lower()]or{}
 if #values==1 then return{status='unique',path=values[1]}end
 local paths={};for i,path in ipairs(values)do paths[i]=path end
 return{status=#values==0 and'missing'or'ambiguous',count=#values,paths=paths}
end
return Index
