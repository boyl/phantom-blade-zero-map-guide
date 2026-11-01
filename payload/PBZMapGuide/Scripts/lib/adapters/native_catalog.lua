-- Fields verified against SubMapItemData in Steam build 26266538.
local Catalog = {}
Catalog.fields = {
    {field='HeiShiItemData', category='blackstone'},
    {field='HupoItemData', category='amber'},
    {field='MemoryFlowerData', category='memory_flower'},
    {field='YaoShiItemData', category='key'},
    {field='PrimaryItemData', category='item'},
    {field='WeaponItemDatas', category='weapon', item_field='WeaponID'},
    {field='ShaChiWeaponItemDatas', category='phantom_edge', item_field='WeaponID'},
    {field='AccessoryItemDatas', category='accessory', item_field='AccessoryID'},
    {field='MedicineItemDatas', category='medicine', item_field='MedicineID'},
    {field='RongShu', category='banyan'},
    {field='LongZhu', category='dragon_pillar'},
    {field='DaoCaoRen', category='scarecrow'},
}
local function name(value)
    local text=value:ToString()
    if text=='' or text=='None' then return nil end
    return text
end
function Catalog.read(asset,build)
    local records, counts, bells = {}, {}, {}
    assert(asset:IsValid(), 'map item data asset unavailable')
    assert(#asset.MapItemDatas<=32, 'unsupported map catalog size')
    asset.MapItemDatas:ForEach(function(key, value)
        local map=name(key:get())
        assert(map, 'map ID absent')
        if map:lower()=='test' then return end
        local data=value:get()
        data.BellDatas:ForEach(function(_,param)
            local bell=param:get()
            local point=bell.Location
            bells[#bells+1]={id=name(bell.BellID),map_id=name(bell.OwnMapID) or map,world={x=point.X,y=point.Y,z=point.Z}}
        end)
        for _,config in ipairs(Catalog.fields) do
            local items=data[config.field]
            assert(#items<=512, 'unsupported category size: '..config.field)
            counts[config.category]=(counts[config.category] or 0)+#items
            items:ForEach(function(_,param)
                local item=param:get()
                local point=item.Location
                local inventoryId=name(item.ItemId)
                local itemId=inventoryId
                if config.item_field then itemId=name(item[config.item_field]) or itemId end
                local nodes,mob,flow={}
                -- Equipment structs inherit MapInventoryItemData, including event provenance.
                item.NodeGuids:ForEach(function(_,node)
                    local id=name(node:get());if id then nodes[#nodes+1]=id end
                end)
                mob=name(item.MobDomainName);flow=name(item.FlowAssetName)
                local pickup=name(item.SaveGuidString)
                local unlocated=point.X==0 and point.Y==0 and point.Z==0 and not pickup and not mob and not flow and #nodes==0
                records[#records+1]={
                    category=config.category, item_id=itemId,
                    inventory_id=inventoryId,
                    pickup_id=pickup, map_id=name(item.OwnMapID) or map,
                    location_status=unlocated and'unavailable'or nil,
                    node_ids=nodes,mob_domain=mob,flow_asset=flow,
                    world={x=point.X,y=point.Y,z=point.Z},
                    requirements={kind='unknown'},
                    evidence={source='native MapItemDataAsset', build=build},
                }
            end)
        end
    end)
    return records, counts, bells
end
return Catalog

