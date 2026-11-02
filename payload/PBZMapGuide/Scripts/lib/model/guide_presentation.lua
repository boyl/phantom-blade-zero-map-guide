local function create(t)
 t=t or function(value)return value end
local P={}
local function chapter(order)return order==0 and t('序章')or t('第')..tostring(order)..t('章')end
local function unique(values)
 local result,seen={},{}
 for _,value in ipairs(values)do if not seen[value]then seen[value]=true;result[#result+1]=value end end
 return result
end
local function rawTagCaption(tag)
 if tag.id~=tag.text then return tag.text end
 local parts={};local first
 for part in tag.text:gmatch('[^%.]+')do
  parts[#parts+1]=part
  if not first then for _,code in utf8.codes(part)do if code>=0x4e00 and code<=0x9fff then first=#parts;break end end end
 end
 return first and table.concat(parts,' · ',first)or tag.text
end
local function tagCaption(tag)
 local text=rawTagCaption(tag)
 local labels={present=t('有记录'),absent=t('无记录'),unknown=t('状态待核实')}
 local state=labels[tag.state]
 if state and tag.source_specific then state=t('该来源')..state end
 return text..(state and(t('（')..state..t('）'))or'')
end
local function itemCaption(item)
 local labels={enough=t('数量足够'),short=t('数量不足'),unknown=t('数量待核实')}
 local state=labels[item.quantity_state]
 return(item.title or t('名称待核实'))..' ×'..item.count..(state and(t('（')..state..t('）'))or'')
end
local function branchCaption(group)
 if type(group.group_index)~='number'or type(group.group_count)~='number'then return t('组合待核实')end
 local mode=type(group.branch_and)=='boolean'and(group.branch_and and t('各组同时成立')or t('各组任选其一'))or t('组间关系待核实')
 return t('组')..group.group_index..'/'..group.group_count..' · '..mode
end
function P.brief(info)
 local lines={info.title or t('获取指引')};local chapters,bells={},{}
 for i in ipairs(info.sources or{})do
  local value=(info.region_chapters or{})[i]
  if value and type(value.order)=='number'then
   local locked=info.source_map_unlocked and info.source_map_unlocked[i]==false
   chapters[#chapters+1]=chapter(value.order)..' · '..((info.regions or{})[i]or value.title)..(locked and t('（地图未解锁）')or'')
  end
 end
 for _,value in ipairs(info.landmarks or{})do bells[#bells+1]=value.name end
 chapters=unique(chapters);bells=unique(bells)
 lines[#lines+1]=t('来源章节：')..(#chapters>0 and table.concat(chapters,' / ',1,math.min(2,#chapters))or t('待核实'))
 lines[#lines+1]=t('附近铃铛：')..(#bells>0 and table.concat(bells,' / ',1,math.min(2,#bells))or t('待核实'))
 return table.concat(lines,'\n')
end
function P.details(info,counts,checks,events,objects,route)
 local lines={}
 local origins,seenOrigins={},{}
 for _,source in ipairs(info.sources or{})do
  for _,kind in ipairs({{source.pickup_id,t('场景交互点')},{source.mob_domain,t('战斗奖励点')}})do
   if type(kind[1])=='string'and kind[1]~=''and kind[1]~='None'and not seenOrigins[kind[2]]then
    seenOrigins[kind[2]]=true;origins[#origins+1]=kind[2]
   end
  end
 end
 local regions=unique(info.regions or{})
 if #regions>0 then lines[#lines+1]=t('获取地区：')..table.concat(regions,' / ')end
 if #origins>0 then lines[#lines+1]=t('来源类型：')..table.concat(origins,' / ')end
 local objectNames,objectStates={},{}
 local objectLabels={chest=t('宝箱'),pickup=t('场景拾取物'),flower=t('记忆之花')}
 for _,object in ipairs(objects or{})do
  if object.status=='read'and objectLabels[object.kind]then objectNames[#objectNames+1]=objectLabels[object.kind]
  elseif object.status~='not_applicable'then
   local label=({not_loaded=t('来源场景未加载'),unsupported=t('来源类型待适配'),unavailable=t('来源读取暂不可用')})[object.status]or t('来源类型待核实')
   objectStates[#objectStates+1]=label
  end
 end
 objectNames=unique(objectNames)
 if #objectNames>0 then lines[#lines+1]=t('来源对象：')..table.concat(objectNames,' / ',1,math.min(2,#objectNames))end
 if #objectStates>0 then lines[#lines+1]=t('另有来源对象：')..table.concat(unique(objectStates),' / ')end
 for _,source in ipairs(info.sources or{})do
  if source.location_status=='unavailable'then lines[#lines+1]=t('精确位置：原生记录未提供可核实坐标');break end
 end
 if info.map_unlock_status=='unavailable'or info.map_unlock_status=='partial'then lines[#lines+1]=t('来源地区解锁：待核实')end
 lines[#lines+1]=t('最早可取章节：尚待前置条件核实')
 local labels={owned=t('已持有'),missing=t('未持有'),unknown=t('待核实')}
 for _,check in ipairs(checks or{})do lines[#lines+1]=t('此障碍所需：')..check.title..t('（')..labels[check.state]..t('）')end
 if counts and counts.total>0 then
  local scope=counts.scope=='item_cycle'and t('本周目')or t('地点记录')
  lines[#lines+1]=string.format(t('%s：已获取 %d · 未获取 %d · 未知 %d'),scope,counts.collected,counts.missing,counts.unknown)
 end
 local requiredItems=events and events.required_items and #events.required_items>0 and events.required_items or info.required_items
 for _,item in ipairs(requiredItems or{})do lines[#lines+1]=t('此障碍所需物品：')..itemCaption(item)end
 if events and events.linked>0 then
  if #(events.interactions or{})==0 then
   if events.challenge then lines[#lines+1]=t('获取方式：完成挑战')
   elseif events.reward then lines[#lines+1]=t('获取方式：原生事件奖励')
   elseif events.loot_match then lines[#lines+1]=t('获取方式：事件掉落（原生配置）')
   elseif events.loot then lines[#lines+1]=t('获取方式：事件奖励（奖励规则待核实）')end
  end
  for i=1,math.min(2,#(events.interactions or{}))do lines[#lines+1]=t('交互选项：')..events.interactions[i]end
  for i=1,math.min(2,#(events.handovers or{}))do
   local group=events.handovers[i];local names={}
   for j=1,math.min(2,#group.items)do names[#names+1]=itemCaption(group.items[j])end
   if #group.items>2 then names[#names+1]=t('等')..#group.items..t('项')end
   if group.unknown>0 then names[#names+1]=t('另有物品待核实')end
   lines[#lines+1]=t('关联交付：')..table.concat(names,t('、'))..t('（条件待核实）')
  end
  if #(events.handovers or{})>2 then lines[#lines+1]=t('另有')..(#events.handovers-2)..t('组交付配置')end
  if #(events.tag_groups or{})>0 then
   for i=1,math.min(2,#events.tag_groups)do
    local group=events.tag_groups[i];local label
    if group.source_role=='branch'then label=(group.blocked and t('关联分支排除')or t('关联分支条件'))..t('（')..branchCaption(group)..t('）')
    elseif group.source_role=='choice'then
     label=group.blocked and t('选项隐藏')or t('选项筛选（')..(group.mode_label or t('匹配关系待核实'))..t('）')
    else label=group.blocked and t('关联排除事件')or t('关联事件')end
    local captions={}
    for j=1,math.min(2,#group.tags)do captions[#captions+1]=tagCaption(group.tags[j])end
    if #group.tags>2 then captions[#captions+1]=t('等')..#group.tags..t('项')end
    lines[#lines+1]=label..t('：')..table.concat(captions,t('、'))
   end
   if #events.tag_groups>2 then lines[#lines+1]=t('另有')..(#events.tag_groups-2)..t('组关联条件')end
  else
  for i=1,math.min(2,#events.tags)do
   local tag=events.tags[i];local label
   if tag.source_role=='choice'then label=tag.blocked and t('选项隐藏：')or t('选项筛选：')
   else label=tag.blocked and t('关联排除事件：')or t('关联事件：')end
   lines[#lines+1]=label..tagCaption(tag)
  end
  end
  for i=1,math.min(2,#(events.branch_states or{}))do
   local labels={['true']=t('当前成立'),['false']=t('当前不成立'),unknown=t('当前状态待核实')}
   lines[#lines+1]=t('关联条件组')..i..t('：')..(labels[events.branch_states[i].state]or labels.unknown)..t('（不代表已可获取）')
  end
  if #(events.branch_states or{})>2 then lines[#lines+1]=t('另有')..(#events.branch_states-2)..t('项条件组判定')end
  for i=1,math.min(2,#events.quests)do lines[#lines+1]=t('关联任务：')..events.quests[i]end
  for i=1,math.min(2,#(events.quest_groups or{}))do
   local group=events.quest_groups[i];local names={}
   for j=1,math.min(2,#group.quests)do names[#names+1]=group.quests[j]end
   if #group.quests>2 then names[#names+1]=t('等')..#group.quests..t('项')end
   if group.unknown>0 then names[#names+1]=group.unknown..t('项说明待核实')end
   local within=group.blocked and t('本组均不成立')or t('本组全部成立')
   lines[#lines+1]=(group.blocked and t('分支排除任务')or t('分支任务条件'))..t('（')..branchCaption(group)..t('；')..within..t('）：')..table.concat(names,t('、'))
  end
  if #(events.quest_groups or{})>2 then lines[#lines+1]=t('另有')..(#events.quest_groups-2)..t('组关联任务条件')end
  if events.quest_unknown>0 then lines[#lines+1]=t('另有任务分支条件：说明待核实')end
  if (events.branch_unknown or 0)>0 then lines[#lines+1]=t('另有关联分支：条件待核实')end
  if (events.item_unknown or 0)>0 then lines[#lines+1]=t('另有物品条件：数量与判定待核实')end
  for i=1,math.min(2,#(events.checks or{}))do
   local check=events.checks[i]
   if check.unavailable then lines[#lines+1]=t('关联检查：条件待核实')
   elseif check.kind=='items'then
    local names={};for j=1,math.min(2,#check.items)do names[#names+1]=itemCaption(check.items[j])end
    if #check.items>2 then names[#names+1]=t('等')..#check.items..t('项')end
    lines[#lines+1]=t('关联物品检查：')..(#names>0 and table.concat(names,t('、'))or t('具体物品待核实'))..t('（判定待核实）')
   elseif check.kind=='cycle'then
    local modes={first=t('一周目'),higher=t('二周目及以后')}
    local states={satisfied=t('当前符合'),not_satisfied=t('当前不符'),unknown=t('当前周目待核实')}
    lines[#lines+1]=t('关联周目路径：')..(modes[check.mode]or t('待核实'))..' · '..(states[check.cycle_state]or states.unknown)
   elseif check.kind=='weapon'then
    local equipped={equipped=t('当前已装备'),not_equipped=t('当前未装备'),unknown=t('装备状态待核实')}
    local current=equipped[check.equipped_state]
    local line=t('关联装备检查：')..(check.title or t('名称待核实'))..t('（判定待核实）')..(current and(' · '..current)or'')
    if check.extra_rule then local labels={soul=t('已铸魂'),not_soul=t('未铸魂')};line=line..' · '..(labels[check.soul_state]or t('铸魂状态待核实'))end
    lines[#lines+1]=line
   elseif check.kind=='quest'then
    lines[#lines+1]=t('关联任务检查：')..(check.title or t('任务说明待核实'))..t('（判定待核实）')
   elseif check.kind=='tags'then
    local names={};for j=1,math.min(2,#check.tags)do names[#names+1]=tagCaption(check.tags[j])end
    if #check.tags>2 then names[#names+1]=t('等')..#check.tags..t('项')end
    lines[#lines+1]=t('关联标签检查：')..(#names>0 and table.concat(names,t('、'))or t('具体标签待核实'))..t('（匹配关系待核实）')
   end
  end
  if #(events.checks or{})>2 then lines[#lines+1]=t('另有')..(#events.checks-2)..t('项关联检查')end
  for i=1,math.min(2,#(events.item_checks or{}))do
   local items=events.item_checks[i].items;local names={}
   for j=1,math.min(2,#items)do names[#names+1]=itemCaption(items[j])end
   if #items>2 then names[#names+1]=t('等')..#items..t('项')end
   lines[#lines+1]=t('关联物品条件：')..table.concat(names,t('、'))..t('（组合与判定待核实）')
  end
  if events.source_status=='loading'then lines[#lines+1]=t('获取线索：解析中…')
  elseif events.source_status=='unavailable'then lines[#lines+1]=t('获取线索：暂不可用')end
  if #(events.hints or{})>0 then lines[#lines+1]=t('游戏内提示：')..table.concat(events.hints,'\n',1,math.min(3,#events.hints))end
  lines[#lines+1]=t('完整前置与路线：尚未核实')
 elseif #origins>0 then lines[#lines+1]=t('获取条件与路线：尚未核实')
 else lines[#lines+1]=t('获取方式与完整前置：暂无可核实的原生说明。')end
 if route then
  if route.status=='reference'then
   lines[#lines+1]=string.format(t('导航路径参考：从%s出发，约 %.0f 米'),route.origin_name or t('参考铃铛'),route.length_cm/100)
   lines[#lines+1]=t('门、机关和跳跃条件仍待核实。')
  elseif route.status=='partial'then lines[#lines+1]=t('导航路径参考：仅有局部路径，未确认抵达来源')
  elseif route.status=='not_loaded'then lines[#lines+1]=t('导航路径参考：来源未加载')
  elseif route.status=='projection_unavailable'then lines[#lines+1]=t('导航路径参考：')..(route.endpoint=='bell'and t('附近铃铛')or t('来源位置'))..t('未匹配到可用导航面')
  elseif route.status=='projection_too_far'then lines[#lines+1]=t('导航路径参考：导航点偏离目标，未采用')
  else lines[#lines+1]=t('导航路径参考：当前无法核实')end
 end
 if #(info.landmarks or{})>0 then lines[#lines+1]=t('附近铃铛按直线距离选取。')end
 return table.concat(lines,'\n')
end
P.withTranslator=create
return P
end
return create()
