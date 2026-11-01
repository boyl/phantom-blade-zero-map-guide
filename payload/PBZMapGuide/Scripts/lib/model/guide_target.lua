local Target={}
function Target.reduce(current,event)
 if event.kind=='select' then return event.info or current end
 if event.kind=='map_changed' then return current end
 if event.kind=='closed' then return nil end
 error('unsupported guide target event')
end
return Target
