-- Mod-owned strings only. Native names and IDs never pass through this catalog.
local I18n={}
local english={
 ['序章']='Prologue',['第']='Chapter ',['章']='',
 ['有记录']='Recorded',['无记录']='Not recorded',['状态待核实']='State unverified',['该来源']='This source: ',
 ['数量足够']='Enough items',['数量不足']='Not enough items',['数量待核实']='Quantity unverified',
 ['名称待核实']='Name unverified',['组合待核实']='Combination unverified',['各组同时成立']='All groups required',['各组任选其一']='Any group required',['组间关系待核实']='Group relationship unverified',['组']='Group ',
 ['获取指引']='Acquisition guide',['（地图未解锁）']=' (map locked)',
 ['来源章节：']='Source chapter: ',['待核实']='Unverified',['附近铃铛：']='Nearby bell: ',
 ['场景交互点']='World interaction',['战斗奖励点']='Combat reward',['获取地区：']='Source region: ',['来源类型：']='Source type: ',
 ['宝箱']='Chest',['场景拾取物']='World pickup',['记忆之花']='Memory flower',['来源场景未加载']='Source area not loaded',['来源类型待适配']='Source type unsupported',['来源读取暂不可用']='Source temporarily unavailable',['来源类型待核实']='Source type unverified',
 ['来源对象：']='Source object: ',['另有来源对象：']='Other source objects: ',
 ['精确位置：原生记录未提供可核实坐标']='Exact location: no verified native coordinates',
 ['来源地区解锁：待核实']='Source map unlock: unverified',
 ['最早可取章节：尚待前置条件核实']='Earliest chapter: prerequisites unverified',
 ['已持有']='Owned',['未持有']='Not owned',['此障碍所需：']='Required for this obstacle: ',
 ['本周目']='This cycle',['地点记录']='Locations',
 ['%s：已获取 %d · 未获取 %d · 未知 %d']='%s: Collected %d · Missing %d · Unknown %d',
 ['此障碍所需物品：']='Items required for this obstacle: ',
 ['获取方式：完成挑战']='Acquisition: complete challenge',
 ['获取方式：原生事件奖励']='Acquisition: event reward',
 ['获取方式：事件掉落（原生配置）']='Acquisition: event drop (native data)',
 ['获取方式：事件奖励（奖励规则待核实）']='Acquisition: event reward (rules unverified)',
 ['交互选项：']='Interaction: ',['等']=' and others (',['项']=' entries)',
 ['另有物品待核实']='Other items unverified',['关联交付：']='Related hand-in: ',['（条件待核实）']=' (conditions unverified)',
 ['另有']='Additional ',['组交付配置']=' hand-in groups',
 ['关联分支排除']='Related excluded branch',['关联分支条件']='Related branch conditions',
 ['选项隐藏']='Hidden option',['选项筛选（']='Option filter (',['匹配关系待核实']='Matching rules unverified',
 ['关联排除事件']='Related excluded event',['关联事件']='Related event',['组关联条件']=' condition groups',
 ['选项隐藏：']='Hidden option: ',['选项筛选：']='Option filter: ',['关联排除事件：']='Related excluded event: ',['关联事件：']='Related event: ',
 ['当前成立']='Currently satisfied',['当前不成立']='Currently not satisfied',['当前状态待核实']='Current state unverified',
 ['关联条件组']='Related condition group ',['（不代表已可获取）']=' (does not confirm availability)',['项条件组判定']=' condition group checks',
 ['关联任务：']='Related quest: ',['项说明待核实']=' descriptions unverified',
 ['本组均不成立']='None in this group',['本组全部成立']='All in this group',
 ['分支排除任务']='Excluded branch quests',['分支任务条件']='Branch quest conditions',['组关联任务条件']=' quest condition groups',
 ['另有任务分支条件：说明待核实']='Other quest branches: unverified',
 ['另有关联分支：条件待核实']='Other related branches: unverified',
 ['另有物品条件：数量与判定待核实']='Other item conditions: quantity and rules unverified',
 ['关联检查：条件待核实']='Related check: conditions unverified',
 ['关联物品检查：']='Related item check: ',['具体物品待核实']='Items unverified',['（判定待核实）']=' (rules unverified)',
 ['一周目']='First cycle',['二周目及以后']='Second cycle or later',['当前符合']='Currently matches',['当前不符']='Currently does not match',['当前周目待核实']='Current cycle unverified',
 ['关联周目路径：']='Related cycle branch: ',
 ['当前已装备']='Equipped',['当前未装备']='Not equipped',['装备状态待核实']='Equipment state unverified',
 ['关联装备检查：']='Related equipment check: ',['已铸魂']='Soul-forged',['未铸魂']='Not soul-forged',['铸魂状态待核实']='Soul-forging state unverified',
 ['关联任务检查：']='Related quest check: ',['任务说明待核实']='Quest description unverified',
 ['关联标签检查：']='Related tag check: ',['具体标签待核实']='Tags unverified',['（匹配关系待核实）']=' (matching rules unverified)',
 ['项关联检查']=' related checks',['关联物品条件：']='Related item conditions: ',['（组合与判定待核实）']=' (combination and rules unverified)',
 ['获取线索：解析中…']='Acquisition clues: loading…',['获取线索：暂不可用']='Acquisition clues: unavailable',
 ['游戏内提示：']='In-game hint: ',['完整前置与路线：尚未核实']='Full prerequisites and route: unverified',
 ['获取条件与路线：尚未核实']='Conditions and route: unverified',
 ['获取方式与完整前置：暂无可核实的原生说明。']='Acquisition and prerequisites: no verified native description.',
 ['导航路径参考：从%s出发，约 %.0f 米']='Route reference: from %s, about %.0f m',
 ['参考铃铛']='Reference bell',['门、机关和跳跃条件仍待核实。']='Doors, mechanisms and jumps remain unverified.',
 ['导航路径参考：仅有局部路径，未确认抵达来源']='Route reference: partial; arrival unconfirmed',
 ['导航路径参考：来源未加载']='Route reference: source not loaded',['导航路径参考：']='Route reference: ',
 ['附近铃铛']='Nearby bell',['来源位置']='Source location',['未匹配到可用导航面']=' has no verified navigation surface',
 ['导航路径参考：导航点偏离目标，未采用']='Route reference: rejected; navigation point too far away',
 ['导航路径参考：当前无法核实']='Route reference: unverified',
 ['附近铃铛按直线距离选取。']='Nearby bells are selected by straight-line distance.',
 ['黑石碎片']='Blackstone fragments',['琥珀碎片']='Amber fragments',['钥匙']='Keys',['道具']='Items',['武器']='Weapons',
 ['影之武装']='Phantom weapons',['配饰']='Accessories',['药品']='Medicine',
 ['榕树挑战']='Banyan challenges',['龙柱挑战']='Dragon pillar challenges',['稻草人挑战']='Scarecrow challenges',
 ['获取指引：']='Acquisition guide: ',['获取来源：当前原生位置表未提供，待核实']='Source: not provided by native location data',
 ['（名称待核实）']=' (name unverified)',['获取地区%s：%s']='Source region%s: %s',['尚未核实']='Unverified',
 ['章节序号待核实']='Chapter number unverified',['地区所属章节：']='Region chapter: ',['地区所属章节：尚未核实']='Region chapter: unverified',
 ['铃铛名称尚未核实']='Bell name unverified',['参考铃铛：%s（直线约 %.0f 米）']='Reference bell: %s (about %.0f m straight-line)',
 ['可走路线与传送解锁尚未核实']='Route and fast-travel unlock unverified',['最早获取条件与路线：尚未核实']='Earliest conditions and route: unverified',
 ['需要影之武装：']='Required phantom weapon: ',['收集品']='Collectible',['（类型尚未核实）']=' (type unverified)',
 ['点位获取指引']='Location guide',['该点位的全部奖励尚未核实']='All rewards at this location remain unverified',
 ['展开详情']='Show details',['收起详情']='Hide details',
 ['全部类别']='All categories',['钥匙与任务道具']='Keys and quest items',['普通道具']='Other items',
 ['全部进度']='All progress',['未获取']='Missing',['已获取']='Collected',['状态未知']='Unknown state',['当前可获取']='Available now',['未知']='Unknown',
 ['收集清单']='Checklist',['复位']='Reset',['名称 / 拼音 / 首字母 / 地区']='Name / pinyin / initials / region',
 ['全部地区']='All regions',['上一页']='Previous',['下一页']='Next',['收集品名称']='Collectible name',
 ['地区 · 未获取']='Region · Missing',
 ['530 处 · 未获取 429 · 已获取 101 · 未知 0']='530 locations · Missing 429\nCollected 101 · Unknown 0',
 ['收起']='Hide',['正在准备清单…']='Preparing checklist…',
 ['%d 处 · 未获取 %d · 已获取 %d · 未知 %d']='%d locations · Missing %d\nCollected %d · Unknown %d',
 ['清单暂不可用']='Checklist unavailable',['正在准备清单 %d / %d']='Preparing checklist %d / %d',
 ['正在读取当前进度…']='Reading progress…',['获取处：']='Source: ',
 ['所需物品获取指引']='Required item guide',['需要物品：']='Required item: ',
 ['进行中']='In progress',['已完成']='Completed',['已结束']='Finished',['失败']='Failed',['未开始']='Not started',
 ['（要求']=' (requires ',['非']='not ',[' · 当前']=' · Current: ',
 ['（']=' (',['）']=')',['）：']='): ',['：']=': ',['、']=', ',['；']='; ',
}
function I18n.normalize(tag)
 if type(tag)~='string'then return'en'end
 tag=tag:match('^%s*(.-)%s*$'):lower():gsub('_','-')
 return(tag=='zh'or tag:match('^zh%-[%a%d]+'))and'zh'or'en'
end
function I18n.new(tag)
 local self={language=I18n.normalize(tag)}
 self.text=function(key)
  if self.language=='zh'then return key end
  assert(english[key]~=nil,'Missing English Mod translation: '..tostring(key))
  return english[key]
 end
 function self:setLanguage(value)self.language=I18n.normalize(value)end
 return self
end
return I18n
