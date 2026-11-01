-- Static level-loot configuration only. Never invokes the game's loot generator.
local Loot={}
local function integer(value)
 assert(type(value)=='number'and value%1==0,'invalid native loot integer');return value
end
local function id(value)
 local text=value:ToString();assert(text~=''and text~='None','native loot ID unavailable');return text
end
function Loot.read(deps)
 local asset=deps.load('/Game/PBZContent/DataTable/DT_LevelLootDataTable.DT_LevelLootDataTable')
 if not asset or not asset:IsValid()then return{status='unavailable'}end
 assert(asset:GetRowStruct():GetFullName()=='ScriptStruct /Script/ProjectPBZ.LevelLootTableData','unsupported native loot row contract')
 local rows=asset:GetRowMap();local result={status='read',by_id={}};local count=0
 for _,row in pairs(rows)do
  count=count+1;assert(count<=4096,'native loot row bound')
  local key=id(row.LootItemID):lower();assert(not result.by_id[key],'duplicate native loot ID')
  local levels={};result.by_id[key]=levels
  local entries=row.EntryDatas;assert(#entries<=64,'native loot level bound')
  entries:ForEach(function(_,parameter)
   local entry=parameter:get();local level=integer(entry.EnemyLevel)
   assert(not levels[level],'duplicate native loot level');local items={};levels[level]=items
   for _,spec in ipairs({{'LootItems','inventory','ItemId'},{'Weapons','weapon','WeaponID'},{'Medicines','medicine','MedicineID'},{'Accessories','accessory','AccessoryID'}})do
    local values=entry[spec[1]];assert(#values<=256,'native loot entry bound')
    values:ForEach(function(_,parameter)
     local value=parameter:get();local item={category=spec[2],id=id(value[spec[3]])}
     if spec[1]=='LootItems'then
      item.min=integer(value.MinAmount);item.max=integer(value.MaxAmount)
      assert(item.min>=0 and item.max>=item.min,'invalid native loot range')
     elseif spec[1]=='Weapons'then
      assert(type(value.IsMainWeapon)=='boolean','invalid native weapon namespace')
      if not value.IsMainWeapon then item.category='phantom_edge'end
     end
     items[#items+1]=item
    end)
   end
  end)
 end
 return result
end
function Loot.resolve(index,config,level)
 if index.status~='read'then return{status='unavailable'}end
 local levels=index.by_id[tostring(config):lower()]
 if not levels then return{status='missing'}end
 local items=levels[level]
 if not items then return{status='unknown_level'}end
 return{status='read',items=items}
end
return Loot
