-- Trace related native conditions, without claiming every incoming branch is mandatory.
local Evidence={}
local function same(a,b)return a and b and a:lower()==b:lower()end
local function rewardMatches(node,record)
 if node.signal_mode~=0 then return false end
 if node.kind=='weapon'then
  return same(node.weapon_id,record.item_id)and((record.category=='weapon'and node.normal_weapon)or(record.category=='phantom_edge'and not node.normal_weapon))
 elseif node.kind=='medicine'then return record.category=='medicine'and same(node.medicine_id,record.item_id)
 elseif node.kind=='items'then
  for _,item in ipairs(node.items)do if item.count>0 and(same(item.id,record.inventory_id)or same(item.id,record.item_id))then return true end end
 end
 return false
end
function Evidence.inspect(graph,record)
 local result={targets=0,reward=false,loot=false,loot_match=false,challenge=false,branch_unknown=0,branch_nodes={},dialogues={},conditions={},quest_groups={},checks={},handovers={},interactions={},complete=false}
 if graph.status~='read'then return result end
 local reverse={}
 for id,node in pairs(graph.nodes)do for _,edge in ipairs(node.edges)do
  local target=graph.nodes[edge.target]
  if node.signal_mode~=1 and target and target.signal_mode~=1 then
   reverse[edge.target]=reverse[edge.target]or{};reverse[edge.target][#reverse[edge.target]+1]={source=id,output=edge.output}
  end
 end end
 local queue,seen={},{}
 for _,value in ipairs(record.node_ids or{})do
  local tail=value:match('([^_]+)$')or value;local id=tail:gsub('%-',''):upper()
  if #id==32 and id:match('^%x+$')and graph.nodes[id]and not seen[id]then
   seen[id]=true;queue[#queue+1]=id;result.targets=result.targets+1
   if rewardMatches(graph.nodes[id],record)then result.reward=true end
   local node=graph.nodes[id]
   if node.signal_mode==0 then
    if node.kind=='loot_config'and node.loot_id and node.loot_id~=''and node.loot_id~='None'then result.loot=true end
    if node.kind=='loot_config'then
     for _,item in ipairs(node.loot_items or{})do
      local matches=item.category==record.category and same(item.id,record.item_id)
      if item.category=='inventory'then
       matches=same(item.id,record.inventory_id)or((record.category=='key'or record.category=='item')and same(item.id,record.item_id))
      end
      if matches then result.loot_match=true end
     end
    end
    if node.kind=='challenge'and(record.category=='banyan'or record.category=='dragon_pillar'or record.category=='scarecrow')then result.challenge=true end
   end
  end
 end
 local cursor,choiceSeen=1,{}
 while queue[cursor]do
  local id=queue[cursor];cursor=cursor+1;local node=graph.nodes[id]
  if node.kind=='dialogue_graph'and node.signal_mode==0 then result.dialogues[#result.dialogues+1]={guid=id,asset=node.child_asset}end
  if node.kind=='native_check'and node.signal_mode==0 then result.checks[#result.checks+1]={guid=id,config=node.check,unavailable=node.check==nil}end
  if node.kind=='handover'and node.signal_mode==0 then result.handovers[#result.handovers+1]={guid=id,items=node.handover_items,unavailable=node.handover_items==nil}end
  if node.kind=='tag_condition'and node.signal_mode==0 then result.conditions[#result.conditions+1]=node end
  for _,edge in ipairs(reverse[id]or{})do
   local parent=graph.nodes[edge.source]
   if parent.kind=='cycle_branch'and parent.signal_mode==0 then
    local mode=({['一周目']='first',['高周目']='higher'})[edge.output]
    result.checks[#result.checks+1]={guid=edge.source,output=edge.output,config=mode and{kind='cycle',mode=mode}or nil,unavailable=mode==nil}
   end
   if parent.kind=='tag_branch'and parent.signal_mode==0 then
    if edge.output:lower()=='true'and parent.branch_groups then
     result.branch_nodes[#result.branch_nodes+1]={guid=edge.source,kind='tag'}
     for i,group in ipairs(parent.branch_groups)do
      result.conditions[#result.conditions+1]={guid=edge.source,group_key=edge.source..'/'..i,group_index=i,group_count=#parent.branch_groups,branch_and=parent.branch_and,source_role='branch',observe=group.allow,block=group.deny,listen_quests={}}
     end
    else result.branch_unknown=result.branch_unknown+1 end
   end
   if parent.kind=='choices'and parent.signal_mode==0 then
    for _,choice in ipairs(parent.choices or{})do
     if choice.output and choice.output==edge.output then
      local key=edge.source..'/'..choice.output
      if not choiceSeen[key]then
       choiceSeen[key]=true;result.conditions[#result.conditions+1]=choice
       if type(choice.title)=='string'and choice.title~=''then result.interactions[#result.interactions+1]=choice.title end
      end
     end
    end
   end
   if parent.kind=='quest_branch'and parent.signal_mode==0 then
    if edge.output:lower()=='true'and parent.branch_groups then
     for i,group in ipairs(parent.branch_groups)do result.quest_groups[#result.quest_groups+1]={guid=edge.source,group_key=edge.source..'/'..i,group_index=i,group_count=#parent.branch_groups,branch_and=parent.branch_and,allow=group.allow,deny=group.deny}end
    else result.branch_unknown=result.branch_unknown+1 end
   end
   if not seen[edge.source]then seen[edge.source]=true;queue[#queue+1]=edge.source end
  end
 end
 return result
end
return Evidence
