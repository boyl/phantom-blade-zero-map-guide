-- Authored lines related to a verified tag producer; never a proof of a complete route.
local Hints={}
function Hints.collect(graph,producer)
 local result={hints={},related=false,complete=false}
 if graph.status~='read'then return result end
 local node=graph.nodes[producer.guid]
 if not node or node.kind~='set_tags'or node.signal_mode~=0 or node.use_cache or node.with_source or producer.with_source then return result end
 for _,tag in ipairs(node.added_tags)do if tag:lower()==producer.tag:lower()then result.related=true;break end end
 if not result.related then return result end
 local queue,seen,texts={producer.guid},{},{};local cursor=1
 while queue[cursor]do
  local id=queue[cursor];cursor=cursor+1
  if not seen[id]then
   seen[id]=true;local current=graph.nodes[id]
   if current and current.signal_mode~=1 then
    if current.kind=='narration'and current.signal_mode==0 and current.narration_text and not texts[current.narration_text]then
     texts[current.narration_text]=true;result.hints[#result.hints+1]=current.narration_text
    end
    for _,edge in ipairs(current.edges)do if not seen[edge.target]then queue[#queue+1]=edge.target end end
   end
  end
 end
 return result
end
return Hints
