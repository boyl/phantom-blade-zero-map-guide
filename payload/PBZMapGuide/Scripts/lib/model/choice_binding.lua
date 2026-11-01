-- Confirm the full configured output name. Never bind by ordinal or label alone.
local Binding={}
function Binding.bind(candidates,edges,localize)
 local outputs={};for _,edge in ipairs(edges)do outputs[edge.output]=true end
 local result={choices={},unbound=0};local prepared,counts={},{}
 for _,candidate in ipairs(candidates)do
  assert(type(candidate.index)=='number'and candidate.index%1==0 and candidate.index>=0,'invalid choice index')
  local title=localize(candidate.text)
  local output=type(title)=='string'and title~=''and(title..tostring(candidate.index))or nil
  prepared[#prepared+1]={candidate=candidate,title=title,output=output}
  if output then counts[output]=(counts[output]or 0)+1 end
 end
 for _,value in ipairs(prepared)do
  local candidate=value.candidate
  if value.output and outputs[value.output]and counts[value.output]==1 then
   result.choices[#result.choices+1]={output=value.output,title=value.title,source_role='choice',
    observe=candidate.filter_tags,block=candidate.hidden_tags,filter_type=candidate.filter_type,
    listen_quests=candidate.listen_quests,exact_quest=candidate.exact_quest}
  else result.unbound=result.unbound+1 end
 end
 return result
end
return Binding
