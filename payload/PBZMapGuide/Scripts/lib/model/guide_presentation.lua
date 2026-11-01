local P={}
local function chapter(order)return order==0 and'序章'or'第'..tostring(order)..'章'end
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
 local labels={present='有记录',absent='无记录',unknown='状态待核实'}
 local state=labels[tag.state]
 if state and tag.source_specific then state='该来源'..state end
 return text..(state and('（'..state..'）')or'')
end
local function itemCaption(item)
 local labels={enough='数量足够',short='数量不足',unknown='数量待核实'}
 local state=labels[item.quantity_state]
 return(item.title or'名称待核实')..' ×'..item.count..(state and('（'..state..'）')or'')
end
local function branchCaption(group)
 if type(group.group_index)~='number'or type(group.group_count)~='number'then return'组合待核实'end
 local mode=type(group.branch_and)=='boolean'and(group.branch_and and'各组同时成立'or'各组任选其一')or'组间关系待核实'
 return'组'..group.group_index..'/'..group.group_count..' · '..mode
end
function P.brief(info)
 local lines={info.title or'获取指引'};local chapters,bells={},{}
 for i in ipairs(info.sources or{})do
  local value=(info.region_chapters or{})[i]
  if value and type(value.order)=='number'then
   local locked=info.source_map_unlocked and info.source_map_unlocked[i]==false
   chapters[#chapters+1]=chapter(value.order)..' · '..((info.regions or{})[i]or value.title)..(locked and'（地图未解锁）'or'')
  end
 end
 for _,value in ipairs(info.landmarks or{})do bells[#bells+1]=value.name end
 chapters=unique(chapters);bells=unique(bells)
 lines[#lines+1]='来源章节：'..(#chapters>0 and table.concat(chapters,' / ',1,math.min(2,#chapters))or'待核实')
 lines[#lines+1]='附近铃铛：'..(#bells>0 and table.concat(bells,' / ',1,math.min(2,#bells))or'待核实')
 return table.concat(lines,'\n')
end
function P.details(info,counts,checks,events,objects,route)
 local lines={}
 local origins,seenOrigins={},{}
 for _,source in ipairs(info.sources or{})do
  for _,kind in ipairs({{source.pickup_id,'场景交互点'},{source.mob_domain,'战斗奖励点'}})do
   if type(kind[1])=='string'and kind[1]~=''and kind[1]~='None'and not seenOrigins[kind[2]]then
    seenOrigins[kind[2]]=true;origins[#origins+1]=kind[2]
   end
  end
 end
 local regions=unique(info.regions or{})
 if #regions>0 then lines[#lines+1]='获取地区：'..table.concat(regions,' / ')end
 if #origins>0 then lines[#lines+1]='来源类型：'..table.concat(origins,' / ')end
 local objectNames,objectStates={},{}
 local objectLabels={chest='宝箱',pickup='场景拾取物',flower='记忆之花'}
 for _,object in ipairs(objects or{})do
  if object.status=='read'and objectLabels[object.kind]then objectNames[#objectNames+1]=objectLabels[object.kind]
  elseif object.status~='not_applicable'then
   local label=({not_loaded='来源场景未加载',unsupported='来源类型待适配',unavailable='来源读取暂不可用'})[object.status]or'来源类型待核实'
   objectStates[#objectStates+1]=label
  end
 end
 objectNames=unique(objectNames)
 if #objectNames>0 then lines[#lines+1]='来源对象：'..table.concat(objectNames,' / ',1,math.min(2,#objectNames))end
 if #objectStates>0 then lines[#lines+1]='另有来源对象：'..table.concat(unique(objectStates),' / ')end
 for _,source in ipairs(info.sources or{})do
  if source.location_status=='unavailable'then lines[#lines+1]='精确位置：原生记录未提供可核实坐标';break end
 end
 if info.map_unlock_status=='unavailable'then lines[#lines+1]='来源地区解锁：待核实'end
 lines[#lines+1]='最早可取章节：尚待前置条件核实'
 local labels={owned='已持有',missing='未持有',unknown='待核实'}
 for _,check in ipairs(checks or{})do lines[#lines+1]='此障碍所需：'..check.title..'（'..labels[check.state]..'）'end
 if counts and counts.total>0 then
  local scope=counts.scope=='item_cycle'and'本周目'or'地点记录'
  lines[#lines+1]=string.format('%s：已获取 %d · 未获取 %d · 未知 %d',scope,counts.collected,counts.missing,counts.unknown)
 end
 local requiredItems=events and events.required_items and #events.required_items>0 and events.required_items or info.required_items
 for _,item in ipairs(requiredItems or{})do lines[#lines+1]='此障碍所需物品：'..itemCaption(item)end
 if events and events.linked>0 then
  if #(events.interactions or{})==0 then
   if events.challenge then lines[#lines+1]='获取方式：完成挑战'
   elseif events.reward then lines[#lines+1]='获取方式：原生事件奖励'
   elseif events.loot_match then lines[#lines+1]='获取方式：事件掉落（原生配置）'
   elseif events.loot then lines[#lines+1]='获取方式：事件奖励（奖励规则待核实）'end
  end
  for i=1,math.min(2,#(events.interactions or{}))do lines[#lines+1]='交互选项：'..events.interactions[i]end
  for i=1,math.min(2,#(events.handovers or{}))do
   local group=events.handovers[i];local names={}
   for j=1,math.min(2,#group.items)do names[#names+1]=itemCaption(group.items[j])end
   if #group.items>2 then names[#names+1]='等'..#group.items..'项'end
   if group.unknown>0 then names[#names+1]='另有物品待核实'end
   lines[#lines+1]='关联交付：'..table.concat(names,'、')..'（条件待核实）'
  end
  if #(events.handovers or{})>2 then lines[#lines+1]='另有'..(#events.handovers-2)..'组交付配置'end
  if #(events.tag_groups or{})>0 then
   for i=1,math.min(2,#events.tag_groups)do
    local group=events.tag_groups[i];local label
    if group.source_role=='branch'then label=(group.blocked and'关联分支排除'or'关联分支条件')..'（'..branchCaption(group)..'）'
    elseif group.source_role=='choice'then
     label=group.blocked and'选项隐藏'or'选项筛选（'..(group.mode_label or'匹配关系待核实')..'）'
    else label=group.blocked and'关联排除事件'or'关联事件'end
    local captions={}
    for j=1,math.min(2,#group.tags)do captions[#captions+1]=tagCaption(group.tags[j])end
    if #group.tags>2 then captions[#captions+1]='等'..#group.tags..'项'end
    lines[#lines+1]=label..'：'..table.concat(captions,'、')
   end
   if #events.tag_groups>2 then lines[#lines+1]='另有'..(#events.tag_groups-2)..'组关联条件'end
  else
  for i=1,math.min(2,#events.tags)do
   local tag=events.tags[i];local label
   if tag.source_role=='choice'then label=tag.blocked and'选项隐藏：'or'选项筛选：'
   else label=tag.blocked and'关联排除事件：'or'关联事件：'end
   lines[#lines+1]=label..tagCaption(tag)
  end
  end
  for i=1,math.min(2,#(events.branch_states or{}))do
   local labels={['true']='当前成立',['false']='当前不成立',unknown='当前状态待核实'}
   lines[#lines+1]='关联条件组'..i..'：'..(labels[events.branch_states[i].state]or labels.unknown)..'（不代表已可获取）'
  end
  if #(events.branch_states or{})>2 then lines[#lines+1]='另有'..(#events.branch_states-2)..'项条件组判定'end
  for i=1,math.min(2,#events.quests)do lines[#lines+1]='关联任务：'..events.quests[i]end
  for i=1,math.min(2,#(events.quest_groups or{}))do
   local group=events.quest_groups[i];local names={}
   for j=1,math.min(2,#group.quests)do names[#names+1]=group.quests[j]end
   if #group.quests>2 then names[#names+1]='等'..#group.quests..'项'end
   if group.unknown>0 then names[#names+1]=group.unknown..'项说明待核实'end
   local within=group.blocked and'本组均不成立'or'本组全部成立'
   lines[#lines+1]=(group.blocked and'分支排除任务'or'分支任务条件')..'（'..branchCaption(group)..'；'..within..'）：'..table.concat(names,'、')
  end
  if #(events.quest_groups or{})>2 then lines[#lines+1]='另有'..(#events.quest_groups-2)..'组关联任务条件'end
  if events.quest_unknown>0 then lines[#lines+1]='另有任务分支条件：说明待核实'end
  if (events.branch_unknown or 0)>0 then lines[#lines+1]='另有关联分支：条件待核实'end
  if (events.item_unknown or 0)>0 then lines[#lines+1]='另有物品条件：数量与判定待核实'end
  for i=1,math.min(2,#(events.checks or{}))do
   local check=events.checks[i]
   if check.unavailable then lines[#lines+1]='关联检查：条件待核实'
   elseif check.kind=='items'then
    local names={};for j=1,math.min(2,#check.items)do names[#names+1]=itemCaption(check.items[j])end
    if #check.items>2 then names[#names+1]='等'..#check.items..'项'end
    lines[#lines+1]='关联物品检查：'..(#names>0 and table.concat(names,'、')or'具体物品待核实')..'（判定待核实）'
   elseif check.kind=='cycle'then
    local modes={first='一周目',higher='二周目及以后'}
    local states={satisfied='当前符合',not_satisfied='当前不符',unknown='当前周目待核实'}
    lines[#lines+1]='关联周目路径：'..(modes[check.mode]or'待核实')..' · '..(states[check.cycle_state]or states.unknown)
   elseif check.kind=='weapon'then
    local equipped={equipped='当前已装备',not_equipped='当前未装备',unknown='装备状态待核实'}
    local current=equipped[check.equipped_state]
    local line='关联装备检查：'..(check.title or'名称待核实')..'（判定待核实）'..(current and(' · '..current)or'')
    if check.extra_rule then local labels={soul='已铸魂',not_soul='未铸魂'};line=line..' · '..(labels[check.soul_state]or'铸魂状态待核实')end
    lines[#lines+1]=line
   elseif check.kind=='quest'then
    lines[#lines+1]='关联任务检查：'..(check.title or'任务说明待核实')..'（判定待核实）'
   elseif check.kind=='tags'then
    local names={};for j=1,math.min(2,#check.tags)do names[#names+1]=tagCaption(check.tags[j])end
    if #check.tags>2 then names[#names+1]='等'..#check.tags..'项'end
    lines[#lines+1]='关联标签检查：'..(#names>0 and table.concat(names,'、')or'具体标签待核实')..'（匹配关系待核实）'
   end
  end
  if #(events.checks or{})>2 then lines[#lines+1]='另有'..(#events.checks-2)..'项关联检查'end
  for i=1,math.min(2,#(events.item_checks or{}))do
   local items=events.item_checks[i].items;local names={}
   for j=1,math.min(2,#items)do names[#names+1]=itemCaption(items[j])end
   if #items>2 then names[#names+1]='等'..#items..'项'end
   lines[#lines+1]='关联物品条件：'..table.concat(names,'、')..'（组合与判定待核实）'
  end
  if events.source_status=='loading'then lines[#lines+1]='获取线索：解析中…'
  elseif events.source_status=='unavailable'then lines[#lines+1]='获取线索：暂不可用'end
  if #(events.hints or{})>0 then lines[#lines+1]='游戏内提示：'..table.concat(events.hints,'\n',1,math.min(3,#events.hints))end
  lines[#lines+1]='完整前置与路线：尚未核实'
 elseif #origins>0 then lines[#lines+1]='获取条件与路线：尚未核实'
 else lines[#lines+1]='获取方式与完整前置：暂无可核实的原生说明。'end
 if route then
  if route.status=='reference'then
   lines[#lines+1]=string.format('导航路径参考：从%s出发，约 %.0f 米',route.origin_name or'参考铃铛',route.length_cm/100)
   lines[#lines+1]='门、机关和跳跃条件仍待核实。'
  elseif route.status=='partial'then lines[#lines+1]='导航路径参考：仅有局部路径，未确认抵达来源'
  elseif route.status=='not_loaded'then lines[#lines+1]='导航路径参考：来源未加载'
  elseif route.status=='projection_unavailable'then lines[#lines+1]='导航路径参考：'..(route.endpoint=='bell'and'附近铃铛'or'来源位置')..'未匹配到可用导航面'
  elseif route.status=='projection_too_far'then lines[#lines+1]='导航路径参考：导航点偏离目标，未采用'
  else lines[#lines+1]='导航路径参考：当前无法核实'end
 end
 if #(info.landmarks or{})>0 then lines[#lines+1]='附近铃铛按直线距离选取。'end
 return table.concat(lines,'\n')
end
return P
