-- Presentation rows carry primitive data; keys never become saved progress flags.
local Collection={}
local order={phantom_edge=1,weapon=2,accessory=3,medicine=4,key=5,item=6,memory_flower=7,blackstone=8,amber=9,banyan=10,dragon_pillar=11,scarecrow=12}
local function normalize(s)return tostring(s or''):lower():gsub('%s+',' '):match('^%s*(.-)%s*$')end
function Collection.prepare(record,key,info,fold,phonetic)
 fold=fold or normalize
 local names={info.title or''};for _,region in ipairs(info.regions or{})do names[#names+1]=region end
 return{key=key,record=record,info=info,
  search=fold(table.concat({info.title or'',info.text or'',record.item_id or'',record.inventory_id or'',record.map_id},' ')),
  phonetic=phonetic and phonetic.compile(table.concat(names,' '))or nil}
end
function Collection.refresh(prepared,snapshot,completion,access,countable)
 local rows={}
 for _,row in ipairs(prepared)do
  if not countable or countable(row.record,snapshot)then
   rows[#rows+1]={key=row.key,record=row.record,info=row.info,search=row.search,phonetic=row.phonetic,
    completion=row.info.metadata_unavailable and'unknown'or completion(row.record,snapshot),
    access=not row.info.metadata_unavailable and access and access(row.record,snapshot)or'unknown'}
  end
 end
 return rows
end
function Collection.build(records,snapshot,describe,completion,fold,access,phonetic,countable)
 local prepared={}
 for i,record in ipairs(records)do
  if not countable or countable(record,snapshot)then
   prepared[#prepared+1]=Collection.prepare(record,i,describe(record),fold,phonetic)
  end
 end
 return Collection.refresh(prepared,snapshot,completion,access)
end
function Collection.select(rows,filter,fold,phonetic)
 filter=filter or{};fold=fold or normalize
 local words={};for word in fold(filter.query):gmatch('%S+')do words[#words+1]=word end
 local result={}
 for _,row in ipairs(rows)do
  local accept=(not filter.category or row.record.category==filter.category)
   and(not filter.map_id or fold(row.record.map_id)==fold(filter.map_id))
   and(not filter.map_ids or filter.map_ids[fold(row.record.map_id)]==true)
   and(not filter.progress or row.completion==filter.progress or(filter.progress=='available' and row.completion=='missing' and row.access=='available'))
  if accept then for _,word in ipairs(words)do if not row.search:find(word,1,true)and not(phonetic and row.phonetic and phonetic.matches(row.phonetic,word))then accept=false;break end end end
  if accept then result[#result+1]=row end
 end
 table.sort(result,function(a,b)
  local x,y=order[a.record.category]or 99,order[b.record.category]or 99
  if x~=y then return x<y end
  if a.record.map_id~=b.record.map_id then return a.record.map_id<b.record.map_id end
  if a.info.title~=b.info.title then return a.info.title<b.info.title end
  return a.key<b.key
 end)
 return result
end
function Collection.page(rows,page,capacity)
 assert(type(capacity)=='number' and capacity>=1 and capacity%1==0,'positive measured row capacity required')
 local pages=math.max(1,math.ceil(#rows/capacity))
 page=math.max(1,math.min(type(page)=='number' and math.floor(page)or 1,pages))
 local selected={};for i=(page-1)*capacity+1,math.min(page*capacity,#rows)do selected[#selected+1]=rows[i]end
 return{rows=selected,page=page,pages=pages,total=#rows}
end
function Collection.counts(rows)
 local counts={total=#rows,collected=0,missing=0,unknown=0}
 for _,row in ipairs(rows)do assert(counts[row.completion]~=nil,'invalid collection state');counts[row.completion]=counts[row.completion]+1 end
 return counts
end
return Collection
