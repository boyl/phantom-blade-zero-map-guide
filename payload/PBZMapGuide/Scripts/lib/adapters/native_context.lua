local Context={}
function Context.one(class)
 local objects=FindObjects(2,class,nil,0,EObjectFlags.RF_ClassDefaultObject,false) or {}
 assert(#objects==1,'expected one active '..class)
 return objects[1]
end
function Context.get()
 return {bell=Context.one('BellManager'),backpack=Context.one('PBZBackPackSubsystem'),text_library=StaticFindObject('/Script/Engine.Default__KismetTextLibrary')}
end
return Context
