local function create(t)
 t=t or function(value)return value end
local Service={}
Service.__index=Service
local readers={
 phantom_edge=function(b,id)return b:GetShaqiWeaponTableData(FName(id)).WeaponName end,
 weapon=function(b,id)return b:GetMainWeaponTableData(FName(id)).WeaponName end,
 accessory=function(b,id)return b:GetAccessoryData(FName(id)).AccessoryName end,
 medicine=function(b,id)return b:GetMedicineData(FName(id)).Name end,
 inventory=function(b,id)return b:GetPropData(FName(id)).ItemName end,
}
local labels={blackstone='黑石碎片',amber='琥珀碎片',memory_flower='记忆之花',key='钥匙',item='道具',weapon='武器',phantom_edge='影之武装',accessory='配饰',medicine='药品',banyan='榕树挑战',dragon_pillar='龙柱挑战',scarecrow='稻草人挑战'}
function Service.new(deps)
 return setmetatable({index=deps.index,context=deps.context,bells=deps.bells,nearest=deps.nearest,read_unlocks=deps.read_unlocks,resolve_text=deps.resolve_text},Service)
end
function Service:localize(text)
 if self.resolve_text then
  local value=self.resolve_text(text);if value then return value end
  local cached=text.ValueCache:ToString();return cached~=''and cached or nil
 end
 local cached=text.ValueCache:ToString()
 if cached~='' then return cached end
 local namespace,key=text.Namespace:ToString(),text.Key:ToString()
 if key=='' then return nil end
 local out={}
 local found=StaticFindObject('/Script/Engine.Default__KismetTextLibrary'):FindTextInLocalizationTable(namespace,key,out,'')
 if found and out.OutText then return out.OutText:ToString() end
 return nil
end
function Service:readName(category,id)
 local reader=assert(readers[category],'unsupported acquisition category')
 return self:localize(reader(self.context().backpack,id))
end
function Service:format(context,key,title,sources,prefix)
 local info={key=key,title=title,lines={(prefix or t('获取指引：'))..title},sources=sources,regions={},source_titles={},landmarks={},region_chapters={}}
 local availability
 if self.read_unlocks then
  local ok,value=pcall(self.read_unlocks,context.bell)
  availability=ok and value or{status='unavailable'}
  info.map_unlock_status=availability.status;info.source_map_unlocked={}
 end
 if #sources==0 then
  info.lines[#info.lines+1]=t('获取来源：当前原生位置表未提供，待核实')
 else
  for i,source in ipairs(sources) do
   if availability and availability.status=='read'then info.source_map_unlocked[i]=availability.maps[source.map_id:lower()]==true end
   info.source_titles[i]=title
   local map=context.bell:GetMapData(FName(source.map_id))
   local chapterId=map.OwnChapterID:ToString()
   local region=self:localize(map.MapName) or (source.map_id..t('（名称待核实）'))
   info.regions[#info.regions+1]=region
   info.lines[#info.lines+1]=string.format(t('获取地区%s：%s'),#sources>1 and tostring(i) or '',region)
   if chapterId~='' and chapterId~='None' then
    local chapter=context.bell:GetChapterData(FName(chapterId))
    local order=chapter.ChapterOrder
    local chapterName=self:localize(chapter.ChapterName) or t('尚未核实')
    info.region_chapters[i]={order=order,title=chapterName,id=chapterId}
    local number=type(order)=='number' and (order==0 and t('序章') or t('第')..order..t('章')) or t('章节序号待核实')
    info.lines[#info.lines+1]=t('地区所属章节：')..number..' · '..chapterName
   else info.lines[#info.lines+1]=t('地区所属章节：尚未核实') end
   if self.nearest and self.bells and source.world then
    local bell,distance=self.nearest(source,self.bells)
    if bell then
     local name=self:localize(context.bell:GetBellData(FName(bell.id)).BellName) or t('铃铛名称尚未核实')
     info.landmarks[#info.landmarks+1]={source_index=i,bell_id=bell.id,map_id=bell.map_id,name=name,distance_cm=distance}
     info.lines[#info.lines+1]=string.format(t('参考铃铛：%s（直线约 %.0f 米）'),name,distance/100)
     info.lines[#info.lines+1]=t('可走路线与传送解锁尚未核实')
    end
   end
  end
 end
 info.lines[#info.lines+1]=t('最早获取条件与路线：尚未核实')
 info.text=table.concat(info.lines,'\n')
 return info
end
function Service:describe(category,itemId)
 local reader=assert(readers[category],'unsupported acquisition category')
 local context=self.context()
 local title=self:localize(reader(context.backpack,itemId)) or (itemId..t('（名称待核实）'))
 local sources
 if category=='inventory' then sources=self.index:findInventory(itemId)else sources=self.index:find(category,itemId)end
 return self:format(context,category..'/'..itemId:lower(),title,sources,category=='phantom_edge' and t('需要影之武装：') or nil)
end
function Service:record(record)
 local context=self.context()
 local identity=record
 if self.index.resolveIdentity then identity=self.index:resolveIdentity(record)end
 local title=labels[record.category]or t('收集品')
 if identity then
  local reader=readers[identity.category]or readers.inventory
  local id=readers[identity.category] and identity.item_id or identity.inventory_id
  if id then title=self:localize(reader(context.backpack,id))or title end
 else title=title..t('（类型尚未核实）')end
 local p=record.world
 return self:format(context,table.concat({record.category,record.map_id,p.x,p.y,p.z},'/'),title,{record})
end
function Service:summary(record,context,cache)
 local identity=record
 if self.index.resolveIdentity then identity=self.index:resolveIdentity(record)end
 local title=labels[record.category]or t('收集品')
 if identity then
  local category=readers[identity.category]and identity.category or'inventory'
  local id=readers[identity.category]and identity.item_id or identity.inventory_id
  if id then
   local key=category..'/'..id:lower()
   if not cache.names[key]then cache.names[key]=self:localize(readers[category](context.backpack,id))or title end
   title=cache.names[key]
  end
 else title=title..t('（类型尚未核实）')end
 local mapId=record.map_id:lower()
 if not cache.regions[mapId]then cache.regions[mapId]=self:localize(context.bell:GetMapData(FName(record.map_id)).MapName)or(record.map_id..t('（名称待核实）'))end
 return{title=title,regions={cache.regions[mapId]},text=cache.regions[mapId],lightweight=true}
end
function Service:records(records)
 assert(#records>0,'point records required')
 if #records==1 then return self:record(records[1])end
 local first=records[1];local names,seen,unknown={}, {},false
 local details={}
 for _,record in ipairs(records)do
  assert(record.map_id:lower()==first.map_id:lower()and record.world.x==first.world.x and record.world.y==first.world.y and record.world.z==first.world.z,'point group spans multiple locations')
  local detail=self:record(record);details[#details+1]=detail
  if record.item_id or record.inventory_id then
   if not seen[detail.title]then seen[detail.title]=true;names[#names+1]=detail.title end
  else unknown=true end
 end
 local title=#names>0 and table.concat(names,t('、'))or t('点位获取指引')
 local p=first.world
 local info=self:format(self.context(),table.concat({'point',first.map_id,p.x,p.y,p.z},'/'),title,{first})
 info.sources=records;info.source_titles={};info.regions={}
 for index in ipairs(records)do info.source_titles[index]=title;info.regions[index]=details[index].regions[1]end
 if unknown then info.lines[#info.lines+1]=t('该点位的全部奖励尚未核实')end
 info.text=table.concat(info.lines,'\n');return info
end
function Service:weapon(weaponId)
 return self:describe('phantom_edge',weaponId)
end
Service.withTranslator=create
return Service
end
return create()
