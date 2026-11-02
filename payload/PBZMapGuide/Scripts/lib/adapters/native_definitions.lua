-- Native item definitions, not a promise of a fixed world source or availability.
local Definitions={}
Definitions.tables={
 {namespace='inventory',path='/Game/PBZContent/DataTable/Item/DT_InventoryData.DT_InventoryData',schema='PBZItemDataStruct',title='ItemName'},
 {namespace='weapon',path='/Game/PBZContent/DataTable/UI/DT_WeaponData.DT_WeaponData',schema='WeaponData',title='WeaponName'},
 {namespace='phantom_edge',path='/Game/PBZContent/DataTable/UI/DT_ShaqiWeaponData.DT_ShaqiWeaponData',schema='ShaqiWeaponData',title='WeaponName'},
 {namespace='medicine',path='/Game/PBZContent/DataTable/UI/DT_MedicineTable.DT_MedicineTable',schema='PBZMedicineDataStruct',title='Name'},
 {namespace='accessory',path='/Game/PBZContent/DataTable/UI/DT_Accessory.DT_Accessory',schema='AccessoryData',title='AccessoryName'},
}
local function text(value)return type(value)=='string'and value or value:ToString()end
function Definitions.read(deps)
 local result={status='read',items={},tables={},errors={}}
 local enums={}
 local function enum(kind,value)
  assert(type(value)=='number'and value%1==0,'invalid native item enum')
  local object=enums[kind]
  if not object then object=deps.find('/Script/ProjectPBZ.'..kind);assert(object and object:IsValid(),'native item enum unavailable');enums[kind]=object end
  local raw=text(object:GetNameByValue(value));local key=raw:match('([^:]+)$')
  -- A qualified EItemDetailType::None is a real value; bare None is an invalid FName.
  assert(raw~='None'and key and key~='','unrecognized native item enum');return key
 end
 for _,spec in ipairs(Definitions.tables)do
  local report={path=spec.path,namespace=spec.namespace,rows=0,accepted=0,filtered=0,failed=0};result.tables[#result.tables+1]=report
  local ok,why=pcall(function()
   local asset=deps.load(spec.path);assert(asset and asset:IsValid(),'native definition table unavailable')
   assert(asset:GetRowStruct():GetFullName()=='ScriptStruct /Script/ProjectPBZ.'..spec.schema,'native definition row contract changed')
   for rowName,row in pairs(asset:GetRowMap())do
    report.rows=report.rows+1;assert(report.rows<=4096,'native definition row bound')
    local valid,value=pcall(function()
     local id=text(row.ItemID);assert(id~=''and id:lower()~='none','definition item ID unavailable')
     local category=spec.namespace
     if spec.namespace=='inventory'then
      if enum('EItemTypes',row.ItemType)~='Item'then return nil end
      category=enum('EItemDetailType',row.ItemDetailType)=='NarrativeItem'and'key'or'item'
     end
     local title=row[spec.title]
     return{id=id,namespace=spec.namespace,category=category,name_key=text(title.Key)}
    end)
    if valid and value then result.items[#result.items+1]=value;report.accepted=report.accepted+1
    elseif valid then report.filtered=report.filtered+1
    else
     report.failed=report.failed+1;result.status='partial'
     result.errors[#result.errors+1]={namespace=spec.namespace,row=tostring(rowName),reason=tostring(value)}
    end
   end
  end)
  report.status=ok and(report.failed>0 and'partial'or'read')or'unavailable'
  if not ok then result.status='partial';report.reason=tostring(why)end
 end
 table.sort(result.items,function(a,b)if a.namespace~=b.namespace then return a.namespace<b.namespace end;return a.id:lower()<b.id:lower()end)
 return result
end
return Definitions
