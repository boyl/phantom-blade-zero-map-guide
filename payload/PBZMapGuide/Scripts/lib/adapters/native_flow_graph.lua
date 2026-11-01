-- Caller must run on the game thread. Load templates only; never initialize or execute a flow.
-- Every returned value is primitive Lua data, not an engine object or borrowed row.
local Graph={}
local function guid(value)
 local a,b,c,d=value.A,value.B,value.C,value.D
 for _,part in ipairs({a,b,c,d})do assert(type(part)=='number'and part%1==0,'invalid native GUID')end
 return string.format('%08X%08X%08X%08X',a%4294967296,b%4294967296,c%4294967296,d%4294967296)
end
local function itemMap(value)
 assert(#value<=256,'unsupported native item map size')
 local result={}
 value:ForEach(function(key,entry)
  local id=key:get():ToString();local count=entry:get()
  assert(type(count)=='number'and count%1==0,'invalid native item count')
  result[#result+1]={id=id,count=count}
 end)
 table.sort(result,function(a,b)return a.id<b.id end)
 return result
end
local function tags(container)
 local values=container.GameplayTags;assert(#values<=256,'unsupported tag count')
 local result={}
 values:ForEach(function(_,entry)result[#result+1]=entry:get().TagName:ToString()end)
 return result
end
local function scalar(node,key,kind)
 local value=node[key];assert(type(value)==kind,'invalid native flow field: '..key);return value
end
local function checkConfig(node,kind)
 if kind=='quest'then
  local enum=node:Reflection():GetProperty('State'):GetEnum()
  assert(enum:GetFullName()=='Enum /Script/ProjectPBZ.EPBZQuestBranchState','unsupported native quest-state enum')
  local state=scalar(node,'State','number');assert(state%1==0 and state>=0 and state<=255,'invalid native quest state')
  local quest=node.Quest;assert(quest:IsValid(),'native quest class unavailable')
  return{kind=kind,quest=quest:GetFullName(),branch=node.BranchID:ToString(),state=state}
 end
 if kind=='items'then return{kind=kind,items=itemMap(node.CheckItems)}end
 if kind=='weapon'then return{kind=kind,id=node.WeaponID:ToString(),main=scalar(node,'Is Main Weapon','boolean'),extra_rule=scalar(node,'MustZhuHun','boolean')}end
 local count=scalar(node,'MatchCount','number');assert(count%1==0,'invalid native tag match threshold')
 return{kind='tags',tags=tags(node.Tags),exact=scalar(node,'ExactMatch','boolean'),match_count=count}
end
local function quests(values)
 assert(#values<=128,'unsupported quest condition count')
 local result={}
 values:ForEach(function(_,entry)
  local value=entry:get();local quest=value.Quest
  local path=quest:IsValid()and quest:GetFullName()or'None'
  result[#result+1]={quest=path,branch=value.BranchID:ToString(),state=scalar(value,'BranchState','number'),
   invert=scalar(value,'Invert','boolean'),group=scalar(value,'CheckQuestGroup','boolean')}
 end)
 return result
end
function Graph.read(path,deps)
 assert(type(path)=='string'and path:match('^/Game/'),'native asset path required')
 if type(deps.load)~='function'then return{path=path,status='unavailable',reason='asset loader unavailable'}end
 local asset=deps.load(path)
 if not asset or not asset:IsValid()then return{path=path,status='unavailable',reason='asset not loaded'}end
 local values=asset.Nodes;assert(#values<=512,'unsupported flow node count')
 local result={path=path,status='read',nodes={}};local pendingNarration,pendingSubgraphs,pendingDialogue={},{},{}
 values:ForEach(function(key,value)
  local id,node=guid(key:get()),value:get()
  assert(node:IsValid(),'invalid flow node')
  assert(guid(node.NodeGuid)==id,'native flow node identity mismatch')
  local class=node:GetClass():GetFullName()
  local entry={guid=id,class=class,signal_mode=scalar(node,'SignalMode','number'),edges={},kind='unknown'}
  assert(entry.signal_mode==0 or entry.signal_mode==1 or entry.signal_mode==2,'unsupported native flow signal mode')
  local connections=node.Connections;assert(#connections<=128,'unsupported connection count')
  connections:ForEach(function(pin,connection)
   local output=pin:get():ToString();local target=connection:get()
   local targetId=guid(target.NodeGuid);local input=target.PinName:ToString()
   entry.edges[#entry.edges+1]={output=output,target=targetId,input=input}
  end)
  if class:match('/DialogueGraphNew%.DialogueGraphNew_C$')then
   entry.kind='dialogue_graph';if deps.read_subgraph then pendingSubgraphs[id]=node end
  elseif class:match('/DialogueNode%.DialogueNode_C$')then
   entry.kind='dialogue_line';if deps.read_dialogue then pendingDialogue[id]=node end
  elseif class:match('/GetItems%.GetItems_C$')then
   entry.kind='items';entry.items=itemMap(node.ItemIDAndCount)
  elseif class:match('/GiveItems%.GiveItems_C$')then
   entry.kind='handover'
   local ok,value=pcall(itemMap,node.ItemIDAndCount)
   if ok then entry.handover_items=value else entry.handover_error=tostring(value)end
  elseif class:match('/AddWeaponItem%.AddWeaponItem_C$')then
   entry.kind='weapon';entry.weapon_id=node.WeaponID:ToString();entry.normal_weapon=scalar(node,'IsNormalWeapon','boolean')
  elseif class:match('/AddMedicine%.AddMedicine_C$')then
   entry.kind='medicine';entry.medicine_id=node.MedicineID:ToString()
  elseif class:match('/LootItems%.LootItems_C$')then
   entry.kind='loot_config';entry.loot_id=node.LootItemID:ToString();entry.loot_level=scalar(node,'LootLevel','number')
   assert(entry.loot_level%1==0,'invalid native loot level')
   if deps.read_loot then
    local config=deps.read_loot(entry.loot_id,entry.loot_level)
    entry.loot_status=config.status
    if config.status=='read'then entry.loot_items=config.items end
   end
  elseif class=='BlueprintGeneratedClass /Game/PBZContent/Blueprint/FlowGraph/FlowGraphNode/CheckCycleCount.CheckCycleCount_C'then
   entry.kind='cycle_branch'
  elseif class:match('/CompleteChallenge%.CompleteChallenge_C$')then
   entry.kind='challenge';entry.challenge_type=scalar(node,'ChallengeType','number')
   assert(entry.challenge_type>=0 and entry.challenge_type<=255 and entry.challenge_type%1==0,'invalid native challenge enum')
  elseif class:match('/AddChoices%.AddChoices_C$')then
   entry.kind='choices';entry.choices={};entry.choice_details='unavailable'
   if deps.read_choices then
    entry.choice_candidates=deps.read_choices(node,{tags=tags,quests=quests});entry.choice_details='unbound'
   end
  elseif class:match('/CheckDoorLockItems%.CheckDoorLockItems_C$')or class:match('/IsEquipWeapon%.IsEquipWeapon_C$')or class:match('/IsTagExist%.IsTagExist_C$')or class:match('/IsQuestExist%.IsQuestExist_C$')then
   entry.kind='native_check'
   local kind=class:match('/CheckDoorLockItems%.')and'items'or(class:match('/IsEquipWeapon%.')and'weapon'or(class:match('/IsQuestExist%.')and'quest'or'tags'))
   local ok,value=pcall(checkConfig,node,kind)
   if ok then entry.check=value else entry.check_error=tostring(value)end
  elseif class:match('/IsTagBranch%.IsTagBranch_C$')then
   entry.kind='tag_branch'
   if deps.read_branch then
    local ok,value=pcall(deps.read_branch,node,{tags=tags})
    if ok then entry.branch_groups=value.groups;entry.branch_and=value.conditions_and
    else entry.branch_error=tostring(value)end
   end
  elseif class:match('/IsQuestBranch%.IsQuestBranch_C$')then
   entry.kind='quest_branch'
   if deps.read_quest_branch then
    local ok,value=pcall(deps.read_quest_branch,node)
    if ok then entry.branch_groups=value.groups;entry.branch_and=value.conditions_and
    else entry.branch_error=tostring(value)end
   end
  elseif class:match('/SetTag%.SetTag_C$')then
   entry.kind='set_tags';entry.added_tags=tags(node.AddTags)
   entry.use_cache=scalar(node,'UseCacheTags','boolean');entry.with_source=scalar(node,'WithSource','boolean')
  elseif class:match('/PlaySubTitle%.PlaySubTitle_C$')then
   entry.kind='narration';if deps.read_narration then pendingNarration[id]=node end
  elseif class:match('/Script/ProjectPBZ%.FlowNode_HasWithSourceTag$')then
   entry.kind='tag_condition'
   entry.observe=tags(node.ObserveTags);entry.block=tags(node.BlockTags)
   entry.with_source=scalar(node,'WithSourceTag','boolean');entry.exact=scalar(node,'ExactMatch','boolean')
   entry.match_count=scalar(node,'MatchTagCounts','number');entry.source=node.SourceString:ToString()
   entry.listen_quests=quests(node.ListenQuests);entry.listen_quest_count=#entry.listen_quests;entry.check_item_count=#node.CheckItems
   assert(type(entry.check_item_count)=='number'and entry.check_item_count>=0 and entry.check_item_count%1==0 and entry.check_item_count<=256,'unsupported native item condition count')
   entry.check_items=itemMap(node.CheckItems)
   entry.exact_quest=scalar(node,'ExactMatchListenQuest','boolean')
   entry.quest_details=entry.listen_quest_count==0 and'empty'or'read'
   entry.item_details=entry.check_item_count==0 and'empty'or'read'
  elseif class:match('/Script/Flow%.FlowNode_Start$')then entry.kind='start'end
  assert(result.nodes[id]==nil,'duplicate native node GUID')
  result.nodes[id]=entry
 end)
 for id,node in pairs(pendingNarration)do
  local text,reason=deps.read_narration(node)
  result.nodes[id].narration_text=text;result.nodes[id].narration_error=reason
 end
 for id,node in pairs(pendingSubgraphs)do
  local ok,value=pcall(deps.read_subgraph,node)
  if ok then result.nodes[id].child_asset=value else result.nodes[id].dialogue_error=tostring(value)end
 end
 for id,node in pairs(pendingDialogue)do
  local ok,value=pcall(deps.read_dialogue,node)
  if ok then result.nodes[id].dialogue=value else result.nodes[id].dialogue_error=tostring(value)end
 end
 for _,node in pairs(result.nodes)do
  for _,edge in ipairs(node.edges)do edge.target_known=result.nodes[edge.target]~=nil end
  -- All engine collection iterations have ended before native localization getters run.
  if node.kind=='choices'and node.choice_candidates and deps.bind_choices then
   local bound=deps.bind_choices(node.choice_candidates,node.edges)
   node.choices=bound.choices;node.choice_unbound=bound.unbound
   node.choice_details=bound.unbound==0 and'bound'or'partial'
  end
 end
 return result
end
return Graph
