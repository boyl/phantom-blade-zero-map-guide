local Layout={}
function Layout.calculate(width,height,rowHeight,measured,anchor)
 assert(width>=480 and height>=480,'collection viewport is too small')
 assert(type(rowHeight)=='number' and rowHeight>0,'measured row height required')
 local w=math.min(480,width-48)
 anchor=anchor or{x=32,y=math.min(180,height*0.22),width=math.min(440,width*0.34)}
 local y=math.max(16,anchor.y)
 local h=math.min(700,height-y-16)
 measured=measured or{}
 local titleHeight=math.max(38,measured.title or 0)
 local searchHeight=math.max(38,measured.search or 0)
 local comboHeight=math.max(36,measured.combo or 0)
 local summaryHeight=math.max(24,measured.summary or 0)
 local ruleY=10+titleHeight+4
 local searchY=ruleY+10
 local categoryY=searchY+searchHeight+8
 local regionY=categoryY+comboHeight+8
 local summaryY=regionY+comboHeight+8
 local start,footer=summaryY+summaryHeight+10,46
 assert(h-start-footer>=rowHeight,'collection row does not fit the viewport')
 return{x=math.max(16,math.min(width-w-16,anchor.x+anchor.width+16)),y=y,width=w,height=h,rowStart=start,rowHeight=rowHeight,
  capacity=math.max(1,math.floor((h-start-footer)/rowHeight)),footerY=h-footer,
  titleHeight=titleHeight,ruleY=ruleY,searchY=searchY,searchHeight=searchHeight,
  categoryY=categoryY,regionY=regionY,comboHeight=comboHeight,summaryY=summaryY,summaryHeight=summaryHeight}
end
return Layout
