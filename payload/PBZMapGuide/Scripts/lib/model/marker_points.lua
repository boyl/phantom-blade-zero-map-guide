-- Several reward records can describe one physical map point.
local Points={}
local function finite(value)return type(value)=='number'and value==value and value<math.huge and value>-math.huge end
function Points.partition(info,allowed)
 local current,other,groups,unknown={},{},{},0
 for index,source in ipairs(info.sources)do
  if source.location_status=='unavailable'then unknown=unknown+1 else
  local p=source.world
  assert(p and finite(p.x)and finite(p.y)and finite(p.z),'finite source coordinates required')
  local key=table.concat({source.map_id:lower(),string.format('%.17g',p.x),string.format('%.17g',p.y),string.format('%.17g',p.z)},'/')
  local group=groups[key]
  if not group then
   group={source=source,titles={},seen={}};groups[key]=group
   local list=allowed[source.map_id:lower()]and current or other;list[#list+1]=group
  end
  local title=(info.source_titles or{})[index]or info.title
  if not group.seen[title]then group.seen[title]=true;group.titles[#group.titles+1]=title end
  end
 end
 for _,list in ipairs({current,other})do for _,group in ipairs(list)do group.title=table.concat(group.titles,'、')end end
 return current,other,unknown
end
return Points
