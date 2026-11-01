-- UE4SS development candidate: native UMG click events and bounded UI sampling.
local Runtime={}
function Runtime.routeReference(info,objects,bells,query,map)
 for i,source in ipairs(info.sources or{})do
  if objects[i]and objects[i].status=='read'then
   local bell,landmark
   for _,candidate in ipairs(info.landmarks or{})do if candidate.source_index==i then landmark=candidate;break end end
   if landmark then for _,candidate in ipairs(bells)do if candidate.id==landmark.bell_id and candidate.map_id:lower()==source.map_id:lower()then bell=candidate;break end end end
   local result=query({loaded=true,source=source,bell=bell,context=map})
   result.origin_name=landmark and landmark.name;result.map_id=source.map_id;return result
  end
 end
 return{status='not_loaded',complete=false}
end
function Runtime.selectionMode(origin,navigation)
 local locate=origin=='collection'
 if not locate and navigation then navigation:cancel()end
 return locate
end
function Runtime.refreshRegion(state,markers,mapApi)
 local id=state.map.CurrentDisplayMapID:ToString()
 if id==state.mapId then return false end
 state.mapId=id
 if state.target then
  local drawn,other=markers:show(state.map,state.target,mapApi.allowed(state.map),state.focusOnRegion==true)
  if markers.setRoute then markers:setRoute(state.targetRoute,mapApi.allowed(state.map))end
  state.focusOnRegion=false
  return true,drawn,other
 end
 markers:clear();return true,0,0
end
function Runtime.start(root,options)
 options=options or{}
 local Language=dofile(root..'adapters/native_language.lua')
 local locale=dofile(root..'model/localization.lua').new()
 local t=locale.text
 local previousTarget=_G.PBZMapGuideCandidate and _G.PBZMapGuideCandidate.target
 if _G.PBZMapGuideCandidate then _G.PBZMapGuideCandidate.stop()end
 local Catalog=dofile(root..'adapters/native_catalog.lua')
 local Context=dofile(root..'adapters/native_context.lua')
 local Index=dofile(root..'model/source_index.lua')
 local Nearest=dofile(root..'model/nearest.lua')
 local Service=dofile(root..'adapters/acquisition_service.lua').withTranslator(t)
 local LockInfo=dofile(root..'adapters/native_lock_info.lua').withTranslator(t)
 local Map=dofile(root..'adapters/live_map.lua')
 local Events=dofile(root..'adapters/native_click_latch.lua')
 local Hover=dofile(root..'adapters/native_hover.lua')
 local Pointer=dofile(root..'adapters/native_pointer.lua')
 local Position=dofile(root..'model/panel_position.lua')
 local Preferences=dofile(root..'adapters/panel_preferences.lua')
 local Geometry=dofile(root..'model/map_geometry.lua')
 local Markers=dofile(root..'views/source_markers.lua').withTranslator(t)
 local SourceLayer=dofile(root..'adapters/native_source_layer.lua')
 local MarkerPoints=dofile(root..'model/marker_points.lua')
 local Panel=dofile(root..'views/acquisition_panel.lua').withTranslator(t)
 local Presentation=dofile(root..'model/guide_presentation.lua').withTranslator(t)
 local Pinyin=dofile(root..'model/pinyin_search.lua').new(dofile(root..'data/pinyin_map.lua'))
 local Snapshot=dofile(root..'adapters/native_snapshot.lua')
 local Flower=dofile(root..'adapters/native_flower_counting.lua')
 local Progress=dofile(root..'model/progress.lua')
 local Prerequisites=dofile(root..'model/prerequisites.lua')
 local Target=dofile(root..'model/guide_target.lua')
 local Collection=dofile(root..'model/collection.lua')
 local CollectionLoader=dofile(root..'model/collection_loader.lua')
 local CollectionLayout=dofile(root..'model/collection_layout.lua')
 local CollectionView=dofile(root..'views/collection_panel.lua').withTranslator(t)
 local Rules=dofile(root..'model/rules.lua')
 local Theme=dofile(root..'views/ink_theme.lua')
 local FlowIndex=dofile(root..'adapters/native_flow_index.lua')
 local FlowGraph=dofile(root..'adapters/native_flow_graph.lua')
 local NativeChoices=dofile(root..'adapters/native_choices.lua')
 local NativeBranches=dofile(root..'adapters/native_tag_branches.lua')
 local NativeQuestBranches=dofile(root..'adapters/native_quest_branches.lua')
 local NativeTagState=dofile(root..'adapters/native_tag_state.lua')
 local NativeEquipmentState=dofile(root..'adapters/native_equipment_state.lua')
 local NativeQuestState=dofile(root..'adapters/native_quest_state.lua')
 local NativeBranchState=dofile(root..'adapters/native_branch_state.lua')
 local ConditionState=dofile(root..'model/condition_state.lua')
 local NativeItemRequirement=dofile(root..'adapters/native_item_requirement.lua')
 local ChoiceBinding=dofile(root..'model/choice_binding.lua')
 local SourceDiscovery=dofile(root..'adapters/native_source_discovery.lua')
 local NativeNarration=dofile(root..'adapters/native_narration.lua')
 local SourceHints=dofile(root..'model/source_hints.lua')
 local FlowEvidence=dofile(root..'model/flow_evidence.lua')
 local EventService=dofile(root..'adapters/native_event_service.lua')
 local records,_,bells=Catalog.read(StaticFindObject('/Game/PBZContent/Maps/DT_MapItemData.DT_MapItemData'))
 local MapUnlocks=dofile(root..'adapters/native_map_unlocks.lua')
 local service=Service.new({index=Index.build(records),context=Context.get,bells=bells,nearest=Nearest.bell,read_unlocks=function(bell)return MapUnlocks.read(bell,FName)end,
  resolve_text=function(text)return Language.resolve(text,StaticFindObject)end})
 local deps={find=StaticFindObject,construct=StaticConstructObject,name=FName,text=FText,
  phonetic=Pinyin,
  layout=function()return StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')end,
  report=function(message)print('[PBZMapGuide] '..message..'\n')end,
  mapSystem=function()return Context.one('MapSubsystem')end}
 deps.sourceLayer=function(map)return SourceLayer.create(map,deps)end
 deps.fold=function(value)return StaticFindObject('/Script/Engine.Default__KismetTextLibrary'):TextToLower(FText(tostring(value or''))):ToString():gsub('%s+',' '):match('^%s*(.-)%s*$')end
 local state={active=true,target=previousTarget}
 deps.positionModel=Position;deps.preferences=Preferences.new(root..'../../panel-position.txt')
 deps.guideBounds=function()return state.panel and state.panel.bounds end
 deps.pointer=function(map,needsPosition)return Pointer.read(map,deps.layout(),FName,needsPosition)end
 local NativeLoot=dofile(root..'adapters/native_loot.lua')
 local NativePickup=dofile(root..'adapters/native_pickup_source.lua')
 local pickupDeps={find=StaticFindObject,name=FName,manager=function()return Context.one('PBZLevelActorManager')end}
 local lootIndex
 local function readLoot(id,level)
  if not lootIndex then
   local ok,value=pcall(NativeLoot.read,{load=LoadAsset})
   lootIndex=ok and value or{status='unavailable',reason=tostring(value)}
  end
  return NativeLoot.resolve(lootIndex,id,level)
 end
 local sourceDiscovery;local sourceVersion=0
 local questStates,questStateCount={},0
 local nativeEvents=EventService.new({
  read_index=function()return FlowIndex.read({find=StaticFindObject,name=FName})end,
  read_dialogue_graph=options.dialogue and options.dialogue.read_graph or nil,
  resolve=FlowIndex.resolve,inspect=FlowEvidence.inspect,
  read_graph=function(path)return FlowGraph.read(path,{load=LoadAsset,read_choices=NativeChoices.read,read_branch=NativeBranches.read,read_quest_branch=NativeQuestBranches.read,read_narration=NativeNarration.read,read_loot=readLoot,
   read_subgraph=options.dialogue and options.dialogue.read_subgraph or nil,
   read_dialogue=options.dialogue and options.dialogue.read_line or nil,
   bind_choices=function(candidates,edges)return ChoiceBinding.bind(candidates,edges,function(text)
    local out={};local found=StaticFindObject('/Script/Engine.Default__KismetTextLibrary'):FindTextInLocalizationTable(text.namespace,text.key,out,'')
    if found then return out.OutText:ToString()end
    if text.cache~=''then return text.cache end
   end)end})end,
  read_tag_sources=function()return sourceDiscovery:ensure()end,collect_hints=SourceHints.collect,
  describe_tag=function(tag)return Context.one('EventPipelineManager'):GetTagDescribe({TagName=FName(tag)}):ToString()end,
  query_tag=function(tag,scope)
   local result=NativeTagState.read(tag,scope,{find=StaticFindObject,name=FName,manager=function()return Context.one('EventPipelineManager')end})
   if result.status=='read'then return result.present end
  end,
  query_equipment=function(config)return NativeEquipmentState.read(config,{find=StaticFindObject,name=FName,manager=function()return Context.one('PBZBackPackSubsystem')end})end,
  query_tag_branch=options.branchStates==true and function(path,id)
   local queryDeps={find=StaticFindObject,name=FName,manager=function()return Context.one('EventPipelineManager')end}
   return NativeBranchState.read(path,id,{load=LoadAsset,read=NativeBranches.read,model=ConditionState,
    tags=function(container)local values={};assert(#container.GameplayTags<=256,'native tag count bound');container.GameplayTags:ForEach(function(_,v)values[#values+1]=v:get().TagName:ToString()end);return values end,
    query_allow=function(container)local value=NativeTagState.read_all(container,queryDeps);if value.status=='read'then return value.present end end,
    query_tag=function(tag)local value=NativeTagState.read(tag,{},queryDeps);if value.status=='read'then return value.present end end})
  end or nil,
  query_item=function(id,count)
   local result=NativeItemRequirement.read(id,count,{find=StaticFindObject,name=FName,manager=function()return Context.one('PBZBackPackSubsystem')end})
   if result.status=='read'then return result.enough end
  end,
  describe_item=function(id)return service:readName('inventory',id)end,
  describe_weapon=function(category,id)if #service.index:find(category,id)>0 then return service:readName(category,id)end end,
  describe_filter=function(value)return NativeChoices.filterLabel(value,{find=StaticFindObject})end,
  describe_quest=function(condition)
   local component=StaticFindObject('/Script/ProjectPBZ.Default__PBZBlueprintFunctionLibrary'):GetPBZNarrativeComp(state.map)
   if not component:IsValid()then return nil end
   local matches={}
   component.QuestList:ForEach(function(_,value)
    local quest=value:get()
    if quest:IsValid()and quest:GetClass():GetFullName()==condition.quest then matches[#matches+1]=quest end
   end)
   if #matches~=1 then return nil end
   -- End the borrowed array iteration before invoking a native text getter.
   local title=matches[1]:GetQuestName():ToString()
   local enum=StaticFindObject('/Script/ProjectPBZ.EPBZQuestBranchState')
   if enum:IsValid()then
    local key=enum:GetNameByValue(condition.state):ToString():match('([^:]+)$')
    local labels={InProcess='进行中',Completed='已完成',Finished='已结束',Failed='失败',NotStarted='未开始'}
    if labels[key]then title=title..t('（要求')..(condition.invert and t('非')or'')..t(labels[key])..t('）')end
    -- New getters remain opt-in until their actual runtime signatures are verified.
    if options.questStates==true then
     local cacheKey=tostring(condition.quest)..'\0'..tostring(condition.branch)..'\0'..tostring(condition.group)
     local current=questStates[cacheKey]
     if not current then
      current={status='budget_exhausted'}
      if questStateCount<8 then
       questStateCount=questStateCount+1
       current=NativeQuestState.read(matches[1],condition,{find=StaticFindObject,name=FName})
      end
      questStates[cacheKey]=current
     end
     local currentKey=current.status=='read'and enum:GetNameByValue(current.state):ToString():match('([^:]+)$')
     title=title..t(' · 当前')..t(labels[currentKey]or'状态待核实')
    end
   end
   return title
  end})
 sourceDiscovery=SourceDiscovery.new({
  read_index=function()return nativeEvents:get_index()end,
  read_graph=function(path)return FlowGraph.read(path,{load=LoadAsset})end})
 local traceCounter,traceActive=0,false
 local function trace(stage)
  if stage=='validate'then
   traceCounter=traceCounter+1
   if traceCounter>1800 then
    if traceActive then print('[PBZMapGuide] TRACE stopped after bounded diagnostic window\n')end
    traceActive=false;return
   end
   if options.tracePath and(traceCounter==1 or traceCounter%10==0)then
    local file=io.open(options.tracePath,'r');traceActive=file~=nil;if file then file:close()end
   end
  end
  if traceActive then print('[PBZMapGuide] TRACE '..stage..'\n')end
 end
 local events=Events.new({name=FName,sentinel=function(receiver)return StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),receiver)end,report=function(s)print('[PBZMapGuide] '..s..'\n')end})
 local markers=Markers.new(deps,Geometry,MarkerPoints,options.routes and options.routes.view)
 local function readSnapshot(selected)
  local context={game=Context.one('PBZGameSystem'),backpack=Context.one('PBZBackPackSubsystem'),actors=Context.one('PBZLevelActorManager'),events=Context.one('EventPipelineManager')}
  local snapshot=Snapshot.read(selected,context,FName)
  local failures={};for key in pairs(snapshot.errors or{})do failures[#failures+1]=key end;table.sort(failures)
  local signature=table.concat(failures,',')
  if signature~=state.snapshotFailures then
   if #failures>0 then print('[PBZMapGuide] Progress channels unavailable: '..signature..'\n')end
   state.snapshotFailures=signature
  end
  snapshot.flower_countable=Flower.read(selected,context.backpack,deps)
  return snapshot
 end
 local hoverController
 local function detach()
  if state.unbind then state.unbind();state.unbind=nil end
  markers:clear()
  if state.collection then state.collection:clear();state.collection=nil end
  if state.panel then state.panel:clear();state.panel=nil end
  if state.receiver and state.receiver:IsValid()then state.receiver:RemoveFromParent()end
  state.receiver=nil;state.map=nil;state.mapId=nil;state.shownKey=nil
  if hoverController then hoverController:reset()end
 end
 function state.stop()
  if not state.active then return end
  state.active=false;sourceDiscovery:stop();detach();events:stop()
  if options.navigation then options.navigation:stop()end
  print('[PBZMapGuide] Native candidate stopped\n')
 end
 local function readDetails(info)
  questStates={};questStateCount=0
  local snapshot=readSnapshot(info.sources)
  local counts=Progress.summary(info.sources,snapshot)
  local checks=Prerequisites.evaluate({{checks=info.required_weapons}},snapshot,function(category,id)return service:readName(category,id)end)
  local eventOk,eventData=pcall(nativeEvents.read,nativeEvents,info.sources,info.required_items,snapshot.cycle)
  if not eventOk then print('[PBZMapGuide] Native event details unavailable: '..tostring(eventData)..'\n')end
  if eventOk then print(string.format('[PBZMapGuide] Native event evidence targets=%d reward=%s tags=%d quests=%d unresolved=%d hints=%d sources=%s\n',eventData.linked,tostring(eventData.reward),#eventData.tags,#eventData.quests,eventData.unresolved,#eventData.hints,eventData.source_status or'not_needed'))end
  if eventOk and eventData.source_status=='unavailable'and not state.sourceErrorLogged then
   state.sourceErrorLogged=true;print('[PBZMapGuide] Native source discovery unavailable: '..tostring(sourceDiscovery.state.error)..'\n')
  end
  sourceVersion=sourceDiscovery.state.version
  local objects={}
  for _,record in ipairs(info.sources)do objects[#objects+1]=NativePickup.read(record,{find=StaticFindObject,lookup=function(id)return NativePickup.lookup(id,pickupDeps)end})end
  if options.routes and not state.routeRequested then
   state.routeRequested=true
   state.targetRoute=Runtime.routeReference(info,objects,service.bells,options.routes.read,state.map)
  end
  if options.routes then markers:setRoute(state.targetRoute,Map.allowed(state.map))end
  return Presentation.details(info,counts,checks,eventOk and eventData or nil,objects,state.targetRoute)
 end
 local function display(map,info,origin)
  state.routeRequested=false;state.targetRoute=nil
  local navigate=Runtime.selectionMode(origin,options.navigation)
  state.focusOnRegion=false
  hoverController:reset()
  print('[PBZMapGuide] Rendering '..info.title..' on '..map.CurrentDisplayMapID:ToString()..'\n')
  trace('show_sources');local drawn,other=markers:show(map,info,Map.allowed(map),navigate)
  trace('read_progress');state.targetDetails=readDetails(info)
  state.panel:set(Presentation.brief(info),state.targetDetails)
  state.shownKey=info.key
  if navigate and options.navigation then
   local ok,status=pcall(options.navigation.request,options.navigation,map,info)
   state.focusOnRegion=ok and status=='pending'
   print('[PBZMapGuide] Source navigation '..(ok and status or('unavailable: '..tostring(status)))..'\n')
  end
  print('[PBZMapGuide] Confirmed '..info.title..' current='..drawn..' other='..other..'\n')
 end
 local function selectedInfo(map)
  return Map.selection(map,records,LockInfo,{service=service,
   switch_class=StaticFindObject('/Script/ProjectPBZ.SwitchLockObject'),
   find_lock=function(mapId,id)return Context.one('MapSubsystem'):FindTrackableLock(mapId,id)end})
 end
 hoverController=Hover.new({
  readKey=function(map)return map.SlotWidgetGroup:GetSelectedSlotID():ToString()end,
  readInfo=selectedInfo,
  show=function(info)state.panel:set(Presentation.brief(info));state.shownKey=info.key end,
  restore=function(info)state.panel:set(Presentation.brief(info),state.targetDetails);state.shownKey=info.key end,
  hide=function()state.panel:hide();state.shownKey=nil end})
 local function click(map)
  if not state.active or not Map.visible(map) or map.BigMapMode then return end
  print('[PBZMapGuide] Native click selected='..map.SlotWidgetGroup:GetSelectedSlotID():ToString()..'\n')
  local info=selectedInfo(map)
  state.target=Target.reduce(state.target,{kind='select',info=info})
  if not info then return end
  display(map,info,'map')
 end
 local function hover(map)
  local blocked=map.BigMapMode or state.panel.expanded or state.panel:isInteracting()
  local collection=state.collection
  if collection and collection.open and(collection.dragActive or(collection.border:IsValid()and collection.border:IsHovered()))then blocked=true end
  hoverController:update(map,state.target,blocked)
 end
 local function attach(map)
  state.map=map;state.mapId=map.CurrentDisplayMapID:ToString()
  locale:setLanguage(Language.read({find=StaticFindObject,report=deps.report}))
  deps.language=locale.language
  deps.report('Mod UI language='..locale.language)
  if options.theme~=false then deps.theme=Theme.new(deps)else deps.theme=nil end
  state.panel=Panel.new(deps,map,events)
  local receiver=StaticConstructObject(StaticFindObject('/Script/UMG.Button'),map)
  state.receiver=receiver;receiver:SetVisibility(1);map.MapClickSurface:GetParent():AddChild(receiver)
  state.unbind=events:bindClick(map.MapClickSurface,receiver,function()click(map)end)
  local metadata={names={},regions={}}
  local loader=CollectionLoader.new({records=records,context=Context.get,report=deps.report,
   prepare=function(record,key,context)return Collection.prepare(record,key,service:summary(record,context,metadata),deps.fold,Pinyin)end,
   snapshot=function()return readSnapshot(records)end,
   refresh=function(prepared,snapshot)return Collection.refresh(prepared,snapshot,Progress.completion,function(record,snap)return Rules.evaluate(record.requirements,snap.facts or{})end,Progress.countable)end})
  local ok,collection=pcall(CollectionView.new,deps,map,events,Collection,CollectionLayout,loader,function(_,record)
   local info=service:record(record);state.target=Target.reduce(state.target,{kind='select',info=info});display(map,info,'collection')
  end)
  if ok then state.collection=collection else print('[PBZMapGuide] Collection UI unavailable: '..tostring(collection)..'\n')end
  if state.target then display(map,state.target)end
  print('[PBZMapGuide] Native map attached '..state.mapId..'\n')
 end
 local function step()
  trace('validate')
  if options.navigation then
   local status=options.navigation:step()
   if status~=state.navigationStatus then
    state.navigationStatus=status
    print('[PBZMapGuide] Source navigation state='..status..(options.navigation.error and(' reason='..options.navigation.error)or'')..'\n')
   end
  end
  sourceDiscovery:step()
  if state.map then
   if not Map.visible(state.map)then
    state.target=Target.reduce(state.target,{kind='closed'});detach()
   elseif state.map.CurrentDisplayMapID:ToString()~=state.mapId then
    local _,drawn,other=Runtime.refreshRegion(state,markers,Map)
    hoverController:reset()
    print('[PBZMapGuide] Native region refreshed '..state.mapId..' sources='..drawn..' other='..other..'\n')
   end
  end
  if not state.map then local map=Map.active();if map then trace('attach');attach(map)end end
  if sourceDiscovery.state.version~=sourceVersion then
   sourceVersion=sourceDiscovery.state.version
   print(string.format('[PBZMapGuide] Native source discovery %s read=%d failed=%d\n',sourceDiscovery.state.status,sourceDiscovery.state.read,sourceDiscovery.state.failed))
   if state.target and state.panel then
    state.targetDetails=readDetails(state.target)
    if state.shownKey==state.target.key then state.panel:updateDetail(state.targetDetails)end
   end
  end
  if state.map then
   trace('events');events:poll();trace('hover');hover(state.map)
   trace('markers');markers:update();trace('panel');state.panel:layout()
   if state.collection then trace('collection');state.collection:update()end
   trace('frame_done')
  end
 end
 local function pump()
  if not state.active then return end
  ExecuteInGameThread(function()
   if not state.active then return end
   local ok,message=pcall(step)
   if not ok then
    print('[PBZMapGuide] Native candidate error: '..tostring(message)..'\n')
    state.stop();return
   end
   if state.active then ExecuteWithDelay(state.collection and state.collection.dragActive and 33 or 100,pump)end
  end)
 end
 _G.PBZMapGuideCandidate=state
 pump()
 print('[PBZMapGuide] Native candidate loaded; records='..#records..'\n')
 return state
end
return Runtime
