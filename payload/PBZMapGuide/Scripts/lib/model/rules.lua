-- Pure rules: consumes the current snapshot; never retains game objects or history.
local Rules = {}
function Rules.evaluate(condition, facts)
    if condition == nil then return 'unknown' end
    if condition.kind == 'unknown' then return 'unknown' end
    if condition.kind == 'fact' then
        assert(type(condition.key)=='string' and condition.key~='', 'fact key required')
        local value=facts[condition.key]
        assert(value==nil or type(value)=='boolean', 'fact must be boolean or unknown')
        if value==nil then return 'unknown' end
        return value and 'available' or 'blocked'
    end
    assert(condition.kind=='all' or condition.kind=='any', 'unsupported condition kind')
    assert(type(condition.children)=='table', 'condition children required')
    local unknown=false
    for _,child in ipairs(condition.children) do
        local state=Rules.evaluate(child,facts)
        if condition.kind=='all' and state=='blocked' then return 'blocked' end
        if condition.kind=='any' and state=='available' then return 'available' end
        unknown=unknown or state=='unknown'
    end
    if unknown then return 'unknown' end
    return condition.kind=='all' and 'available' or 'blocked'
end
function Rules.status(entry, facts)
    local completed=entry.completion_key and facts[entry.completion_key]
    assert(completed==nil or type(completed)=='boolean', 'completion must be boolean or unknown')
    if completed==true then return 'collected' end
    if completed==nil then return 'unknown' end
    if not entry.sources or #entry.sources==0 then return 'unknown' end
    local alternatives={kind='any',children={}}
    for _,source in ipairs(entry.sources) do
        alternatives.children[#alternatives.children+1]=source.requirements or {kind='unknown'}
    end
    return Rules.evaluate(alternatives,facts)
end
return Rules
