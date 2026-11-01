-- Portable UE4SS entry. Does not depend on a development workspace or pak override.
local source=assert(debug.getinfo(1,'S').source,'script source unavailable'):gsub('^@',''):gsub('\\','/')
local directory=assert(source:match('^(.*)/[^/]+$'),'script directory unavailable')
local root=directory..'/lib/'
local Map
local options={tracePath=directory..'/../.pbz-trace'}
_G.PBZMapGuideBootstrap=dofile(root..'runtime/bootstrap.lua').start(root,{
 queue=ExecuteInGameThread,delay=ExecuteWithDelay,
 options=options,
 prepare=function()
  local ordinary=FindFirstOf('MapSubsystem')
  assert(type(ordinary.GetFullName)=='function','ordinary UObject wrapper unavailable')
  Map=dofile(root..'adapters/live_map.lua')
  local navigator
  local ok,why=pcall(function()
   local Navigation=dofile(root..'adapters/native_navigation.lua')
   navigator=Navigation.new({map=Map,find=StaticFindObject,register=RegisterHook,unregister=UnregisterHook,
    log=function(message)print('[PBZMapGuide] '..message..'\n')end},dofile(root..'model/map_navigation.lua'))
   navigator:start();options.navigation=navigator
  end)
  if not ok then
   if navigator then navigator:stop()end
   print('[PBZMapGuide] Native source navigation unavailable: '..tostring(why)..'\n')
  end
 end,
 ready=function()
  return StaticFindObject('/Game/PBZContent/Maps/DT_MapItemData.DT_MapItemData'):IsValid() and Map.active()~=nil
 end,
 load=function()return dofile(root..'runtime/native_candidate.lua')end,
 log=function(message)print('[PBZMapGuide] '..message..'\n')end,
})
