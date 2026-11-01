local LockInfo={}
function LockInfo.read(slot,deps)
 local weaponId=slot.ShaChiWeaponID:ToString()
 if weaponId~='' and weaponId~='None' then
  local info=deps.service:weapon(weaponId)
  info.required_weapons={{category='phantom_edge',id=weaponId,title=info.title}}
  return info
 end
 local lock=deps.find_lock(slot.MapID,slot.SlotID:ToString())
 if not lock:IsValid() or not lock:IsA(deps.switch_class) then return nil end
 local info={key='lock/'..slot.SlotID:ToString():lower(),title='所需物品获取指引',lines={},sources={},regions={},source_titles={},region_chapters={},landmarks={},required_items={}}
 local titles={}
 local requirements={}
 lock.NeedItems:ForEach(function(key,value)
  local itemId,count=key:get():ToString(),value:get()
  assert(itemId~='' and itemId~='None','native lock item ID required')
  assert(type(count)=='number' and count>=0 and count%1==0,'native lock quantity must be nonnegative integer')
  requirements[#requirements+1]={id=itemId,count=count}
  assert(#requirements<=32,'unsupported lock requirement count')
 end)
 table.sort(requirements,function(a,b)return a.id<b.id end)
 for _,requirement in ipairs(requirements) do
  local detail=deps.service:describe('inventory',requirement.id)
  titles[#titles+1]=detail.title..' ×'..requirement.count
  info.required_items[#info.required_items+1]={id=requirement.id,title=detail.title,count=requirement.count}
  info.lines[#info.lines+1]='需要物品：'..detail.title..' ×'..requirement.count
  info.lines[#info.lines+1]=detail.text
  local offset=#info.sources
  for index,source in ipairs(detail.sources) do
   info.sources[#info.sources+1]=source
   info.regions[#info.sources]=(detail.regions or{})[index]or source.map_id
   info.source_titles[#info.sources]=detail.title
   info.region_chapters[#info.sources]=(detail.region_chapters or{})[index]
  end
  for _,landmark in ipairs(detail.landmarks or{})do info.landmarks[#info.landmarks+1]={source_index=offset+landmark.source_index,bell_id=landmark.bell_id,map_id=landmark.map_id,name=landmark.name,distance_cm=landmark.distance_cm}end
 end
 if #requirements==0 then return nil end
 info.title=table.concat(titles,'、')
 info.text=table.concat(info.lines,'\n')
 return info
end
return LockInfo
