-- Three-valued composition of verified local predicates, never target accessibility.
local State={}
function State.combine(values,all)
 if type(all)~='boolean'then return'unknown'end
 local unknown=false
 for _,value in ipairs(values)do
  assert(value=='true'or value=='false'or value=='unknown','invalid predicate state')
  if all and value=='false'then return'false'end
  if not all and value=='true'then return'true'end
  if value=='unknown'then unknown=true end
 end
 if unknown then return'unknown'end
 return all and'true'or'false'
end
function State.group(allow,deny)
 local inverted=deny=='true'and'false'or(deny=='false'and'true'or'unknown')
 return State.combine({allow,inverted},true)
end
return State
