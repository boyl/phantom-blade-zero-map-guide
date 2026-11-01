local Service={};Service.__index=Service
function Service.new(deps)return setmetatable({deps=deps,graphs={},dialogueGraphs={}},Service)end
function Service:get_index()
 if not self.index then
  local ok,index=pcall(self.deps.read_index)
  self.index=ok and index or{status='unavailable',reason=tostring(index)}
 end
 return self.index
end
function Service:_graph(path)
 if not self.graphs[path]then
  local ok,value=pcall(self.deps.read_graph,path)
  self.graphs[path]=ok and value or{status='unavailable',reason=tostring(value)}
 end
 return self.graphs[path]
end
function Service:_resolve(record)
 local resolution=self.deps.resolve(self.index,record.flow_asset)
 local paths=resolution.paths
 if resolution.status~='ambiguous'or not paths or #paths<2 or #paths>8 or not record.node_ids or #record.node_ids==0 then return resolution end
 local match
 for _,path in ipairs(paths)do
  local graph=self:_graph(path)
  if graph.status~='read'then return resolution end
  local evidence=self.deps.inspect(graph,record)
  if evidence.targets>0 then
   if match then return resolution end
   match=path
  end
 end
 if match then return{status='unique',path=match,reason='configured_node_guid'}end
 return resolution
end
function Service:read(sources,requiredItems,currentCycle)
 local result={linked=0,reward=false,loot=false,loot_match=false,challenge=false,branch_unknown=0,branch_states={},dialogues={},dialogue_unknown=0,tags={},tag_groups={},quests={},quest_groups={},checks={},handovers={},interactions={},hints={},item_checks={},required_items={},quest_unknown=0,item_unknown=0,unresolved=0,complete=false}
 local seenDialogueAssets,seenDialogueLines,dialogueQueries={},{},0
 local itemStates,itemQueries={},0
 local function itemState(id,count)
  if not self.deps.query_item then return nil end
  if type(id)~='string'or id==''or id=='None'or type(count)~='number'or count%1~=0 or count<=0 then return'unknown'end
  local key=#id..':'..id:lower()..'/'..count
  if itemStates[key]then return itemStates[key]end
  local state='unknown'
  if itemQueries<16 then
   itemQueries=itemQueries+1;local ok,value=pcall(self.deps.query_item,id,count)
   if ok and type(value)=='boolean'then state=value and'enough'or'short'end
  end
  itemStates[key]=state;return state
 end
 for _,item in ipairs(requiredItems or{})do result.required_items[#result.required_items+1]={id=item.id,title=item.title,count=item.count,quantity_state=itemState(item.id,item.count)}end
 local requested=false;for _,record in ipairs(sources)do if record.flow_asset then requested=true;break end end
 if not requested then return result end
 self:get_index()
 local seenTags,seenQuests,seenInteractions,seenItems,seenChecks={},{},{},{},{}
 local seenGroups,seenQuestGroups,seenHandovers={},{},{}
 local seenBranches,branchQueries={},0
 local currentStates,queries={},0
 local equipmentStates,equipmentQueries={},0
 local function equipmentState(config)
  if not self.deps.query_equipment then return nil end
  local key=tostring(config.main)..'/'..config.id:lower()..'/'..tostring(config.extra_rule)
  if equipmentStates[key]then return equipmentStates[key]end
  local result={status='unavailable'}
  if equipmentQueries<8 then
   equipmentQueries=equipmentQueries+1;local ok,value=pcall(self.deps.query_equipment,config)
   if ok and type(value)=='table'then result=value end
  end
  equipmentStates[key]=result;return result
 end
 local function tagState(id,condition)
  if not self.deps.query_tag then return nil end
  local scope={specific=condition.with_source==true,source=condition.source}
  local source=scope.source or''
  local key=(scope.specific and('source/'..#source..':'..source)or'global')..'/'..id:lower()
  if currentStates[key]then return currentStates[key]end
  local state='unknown'
  if queries<32 then
   queries=queries+1;local ok,value=pcall(self.deps.query_tag,id,scope)
   if ok and type(value)=='boolean'then state=value and'present'or'absent'end
  end
  currentStates[key]=state;return state
 end
 for _,record in ipairs(sources)do
  if record.flow_asset then
   local resolution=self:_resolve(record)
   if resolution.status=='unique'then
    local graph=self:_graph(resolution.path)
    local evidence=self.deps.inspect(graph,record)
    result.linked=result.linked+evidence.targets;result.reward=result.reward or evidence.reward
    result.loot=result.loot or evidence.loot==true;result.challenge=result.challenge or evidence.challenge==true
    result.loot_match=result.loot_match or evidence.loot_match==true
    result.branch_unknown=result.branch_unknown+(evidence.branch_unknown or 0)
    if self.deps.read_dialogue_graph then for _,dialogue in ipairs(evidence.dialogues or{})do
     local key=dialogue.asset or(resolution.path..'/'..dialogue.guid)
     if not seenDialogueAssets[key]then
      seenDialogueAssets[key]=true;local value
      if dialogue.asset then
       value=self.dialogueGraphs[dialogue.asset]
       if not value and dialogueQueries<3 then
        dialogueQueries=dialogueQueries+1;local ok,read=pcall(self.deps.read_dialogue_graph,dialogue.asset)
        value=ok and read or{status='unavailable'};self.dialogueGraphs[dialogue.asset]=value
       end
      end
      if value and value.status=='read'then
       result.dialogue_unknown=result.dialogue_unknown+(value.unknown or 0)
       for _,line in ipairs(value.lines or{})do if not seenDialogueLines[line.id]then seenDialogueLines[line.id]=true;result.dialogues[#result.dialogues+1]=line end end
      else result.dialogue_unknown=result.dialogue_unknown+1 end
     end
    end end
    if self.deps.query_tag_branch then for _,branch in ipairs(evidence.branch_nodes or{})do
     local key=resolution.path..'/'..branch.guid
     if branch.kind=='tag'and not seenBranches[key]then
      seenBranches[key]=true;local state='unknown'
      if branchQueries<4 then
       branchQueries=branchQueries+1;local ok,value=pcall(self.deps.query_tag_branch,resolution.path,branch.guid)
       if ok and type(value)=='table'and value.status=='read'and(value.state=='true'or value.state=='false')then state=value.state end
      end
      result.branch_states[#result.branch_states+1]={branch_id=key,state=state,complete=false}
     end
    end end
    for _,entry in ipairs(evidence.handovers or{})do
     local key=resolution.path..'/'..entry.guid
     if not seenHandovers[key]then
      seenHandovers[key]=true;local group={items={},unknown=entry.unavailable and 1 or 0}
      for _,item in ipairs(entry.items or{})do
       if type(item.count)=='number'and item.count%1==0 and item.count>0 and type(item.id)=='string'and item.id~=''and item.id~='None'then
        local ok,title=false,nil
        if self.deps.describe_item then ok,title=pcall(self.deps.describe_item,item.id)end
        group.items[#group.items+1]={id=item.id,count=item.count,title=ok and type(title)=='string'and title~=''and title or nil,quantity_state=itemState(item.id,item.count)}
       else group.unknown=group.unknown+1 end
      end
      if #group.items>0 or group.unknown>0 then result.handovers[#result.handovers+1]=group end
     end
    end
    for _,group in ipairs(evidence.quest_groups or{})do
     for _,role in ipairs({{values=group.allow,blocked=false},{values=group.deny,blocked=true}})do
      local key=resolution.path..'/'..group.group_key..'/'..tostring(role.blocked)
      if #role.values>0 and not seenQuestGroups[key]then
       seenQuestGroups[key]=true;local display={quests={},unknown=0,blocked=role.blocked,branch_id=group.guid and(resolution.path..'/'..group.guid),group_index=group.group_index,group_count=group.group_count,branch_and=group.branch_and}
       for _,quest in ipairs(role.values)do
        local ok,label=pcall(self.deps.describe_quest,quest)
        if ok and type(label)=='string'and label~=''then display.quests[#display.quests+1]=label else display.unknown=display.unknown+1 end
       end
       result.quest_groups[#result.quest_groups+1]=display
      end
     end
    end
    for _,title in ipairs(evidence.interactions or{})do
     if not seenInteractions[title]then seenInteractions[title]=true;result.interactions[#result.interactions+1]=title end
    end
    if evidence.targets==0 then result.unresolved=result.unresolved+1 end
    for _,entry in ipairs(evidence.checks or{})do
     local key=resolution.path..'/'..entry.guid..(entry.output and('/'..entry.output)or'')
     if not seenChecks[key]then
      seenChecks[key]=true
      local config=entry.config;local check={kind=config and config.kind or'unknown',unavailable=entry.unavailable,items={},tags={}}
      result.checks[#result.checks+1]=check
      if config then
       if config.kind=='items'then
        for _,item in ipairs(config.items)do
         local ok,title=false,nil
         if self.deps.describe_item and item.id~=''and item.id~='None'then ok,title=pcall(self.deps.describe_item,item.id)end
         check.items[#check.items+1]={id=item.id,count=item.count,title=ok and type(title)=='string'and title~=''and title or nil,quantity_state=itemState(item.id,item.count)}
        end
       elseif config.kind=='cycle'then
        check.mode=config.mode;check.cycle_state='unknown'
        if type(currentCycle)=='number'and currentCycle>=0 and currentCycle%1==0 and(config.mode=='first'or config.mode=='higher')then
         check.current_cycle=currentCycle+1
         local satisfied=config.mode=='first'and currentCycle==0 or config.mode=='higher'and currentCycle>0
         check.cycle_state=satisfied and'satisfied'or'not_satisfied'
        end
       elseif config.kind=='weapon'then
        check.id=config.id;check.category=config.main and'weapon'or'phantom_edge';check.extra_rule=config.extra_rule
        if self.deps.describe_weapon and config.id~=''and config.id~='None'then local ok,title=pcall(self.deps.describe_weapon,check.category,config.id);if ok and type(title)=='string'and title~=''then check.title=title end end
        local current=equipmentState(config)
        if current then
         check.equipped_state='unknown'
         if current.status=='read'and type(current.equipped)=='boolean'then check.equipped_state=current.equipped and'equipped'or'not_equipped'end
         if config.extra_rule then
          check.soul_state='unknown'
          if current.soul_status=='read'and type(current.soul)=='boolean'then check.soul_state=current.soul and'soul'or'not_soul'end
         end
        end
       elseif config.kind=='quest'then
        check.quest=config.quest;check.branch=config.branch;check.state=config.state
        if self.deps.describe_quest then
         local ok,title=pcall(self.deps.describe_quest,config)
         if ok and type(title)=='string'and title~=''then check.title=title end
        end
       elseif config.kind=='tags'then
        check.exact=config.exact;check.match_count=config.match_count
        for _,tag in ipairs(config.tags)do
         local ok,title=pcall(self.deps.describe_tag,tag)
         check.tags[#check.tags+1]={id=tag,text=ok and type(title)=='string'and title~=''and title or tag,state=tagState(tag,{})}
        end
       end
      end
     end
    end
    for _,condition in ipairs(evidence.conditions)do
     local itemCount=condition.check_item_count or 0
     assert(type(itemCount)=='number'and itemCount>=0 and itemCount%1==0 and itemCount<=256,'invalid native item condition count')
     if itemCount>0 then
      local key=condition.guid and(resolution.path..'/'..condition.guid)or condition
      if not seenItems[key]then
       seenItems[key]=true
       if condition.item_details=='read'and condition.check_items then
        assert(#condition.check_items==itemCount,'native item condition count mismatch')
        local group={items={}}
        for _,item in ipairs(condition.check_items)do
         assert(type(item.id)=='string'and item.id~=''and type(item.count)=='number'and item.count%1==0,'invalid native item condition')
         local ok,title=false,nil
         if self.deps.describe_item then ok,title=pcall(self.deps.describe_item,item.id)end
         group.items[#group.items+1]={id=item.id,count=item.count,title=ok and type(title)=='string'and title~=''and title or nil,quantity_state=itemState(item.id,item.count)}
        end
        result.item_checks[#result.item_checks+1]=group
       else result.item_unknown=result.item_unknown+itemCount end
      end
     end
     for _,group in ipairs({{values=condition.observe,blocked=false},{values=condition.block,blocked=true}})do
      local identity=condition.group_key or condition.guid or condition.output
      local groupKey=identity and(resolution.path..'/'..(condition.guid and'node/'or'choice/')..identity)or condition
      seenGroups[groupKey]=seenGroups[groupKey]or{}
      local displayGroup
      if #group.values>0 and not seenGroups[groupKey][group.blocked]then
       seenGroups[groupKey][group.blocked]=true
       displayGroup={tags={},blocked=group.blocked,source_role=condition.source_role,branch_id=condition.guid and(resolution.path..'/'..condition.guid),group_index=condition.group_index,group_count=condition.group_count,branch_and=condition.branch_and}
       if condition.source_role=='choice'and not group.blocked and self.deps.describe_filter and type(condition.filter_type)=='number'then
        local ok,label=pcall(self.deps.describe_filter,condition.filter_type)
        if ok and type(label)=='string'and label~=''then displayGroup.mode_label=label end
       end
       result.tag_groups[#result.tag_groups+1]=displayGroup
      end
      for _,tag in ipairs(group.values)do
       local key=(condition.source_role or'node')..'/'..(condition.with_source and(condition.source or'')or'global')..'/'..tostring(group.blocked)..'/'..tag
       if not seenTags[key]then
        local ok,label=pcall(self.deps.describe_tag,tag)
        seenTags[key]={id=tag,text=ok and type(label)=='string'and label~=''and label or tag,blocked=group.blocked,source_role=condition.source_role,source_specific=condition.with_source==true,state=tagState(tag,condition)}
        result.tags[#result.tags+1]=seenTags[key]
       end
       if displayGroup then displayGroup.tags[#displayGroup.tags+1]=seenTags[key]end
      end
     end
     for _,quest in ipairs(condition.listen_quests or{})do
      local key=quest.quest..'/'..quest.branch..'/'..quest.state..'/'..tostring(quest.invert)..'/'..tostring(quest.group)
      if not seenQuests[key]then
       seenQuests[key]=true;local ok,label=pcall(self.deps.describe_quest,quest)
       if ok and type(label)=='string'and label~=''then result.quests[#result.quests+1]=label else result.quest_unknown=result.quest_unknown+1 end
      end
     end
    end
   else result.unresolved=result.unresolved+1 end
  else result.unresolved=result.unresolved+1 end
 end
 local positive=false;for _,tag in ipairs(result.tags)do if not tag.blocked and not tag.source_specific then positive=true;break end end
 if positive and self.deps.read_tag_sources then
  local state=self.deps.read_tag_sources();result.source_status=state.status;result.source_unsupported=state.failed
  if state.status=='ready'then
   local seen={}
   for _,tag in ipairs(result.tags)do if not tag.blocked and not tag.source_specific then
    for _,producer in ipairs(state.by_tag[tag.id:lower()]or{})do
     local hints=self.deps.collect_hints(self:_graph(producer.path),producer)
     for _,text in ipairs(hints.hints)do if not seen[text]then seen[text]=true;result.hints[#result.hints+1]=text end end
    end
   end end
  end
 end
 return result
end
return Service
