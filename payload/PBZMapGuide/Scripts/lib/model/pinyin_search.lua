local Search={}
function Search.new(dictionary)
 local P={}
 function P.compile(text)
  local sequence={}
  for _,cp in utf8.codes(text)do
   local literal=utf8.char(cp):lower();local options={literal};local seen={[literal]=true}
   for reading in (dictionary[cp]or''):gmatch('[^,]+')do
    for _,value in ipairs({reading,reading:sub(1,1)})do if not seen[value]then seen[value]=true;options[#options+1]=value end end
   end
   sequence[#sequence+1]=options
  end
  return sequence
 end
 function P.matches(sequence,query)
  query=query:lower():gsub('u:','v'):gsub('ü','v')
  if query==''then return true end
  for start=1,#sequence do
   local positions={[1]=true}
   for index=start,#sequence do
    local nextPositions={}
    for position in pairs(positions)do
     local remaining=query:sub(position)
     for _,option in ipairs(sequence[index])do
      if #remaining<=#option and option:sub(1,#remaining)==remaining then return true end
      if query:sub(position,position+#option-1)==option then nextPositions[position+#option]=true end
     end
    end
    if next(nextPositions)==nil then break end
    positions=nextPositions
   end
  end
  return false
 end
 return P
end
return Search
