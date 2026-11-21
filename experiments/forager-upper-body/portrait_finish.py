"""Finish the hood crown, brow pixels, and the connecting cape panel."""
from pathlib import Path

p=Path("forager.py")
s=p.read_text(encoding="utf8")
s=s.replace('rear_turn=[(x*.94,17.5+.1*(173-z),z+1.05 if z>155 else z+3)',
            'rear_turn=[(x*.94,17.2+.1*(173-z),z-.4 if z>155 else z+3)')
s=s.replace('crown_back=[(x*.75,24+.05*(171-z),157+(z-157)*.79+2)',
            'crown_back=[(x*.75,22.7+.05*(171-z),157+(z-157)*.765+1.6)')
s=s.replace('("olive",(.37,.33,.19),.92),("gold",(.72,.50,.23),.86),',
            '("olive",(.37,.33,.19),.92),("hood-olive",(.36,.34,.19),.92),("gold",(.72,.50,.23),.86),')
s=s.replace('return "olive" if j<5 else "lining"','return "hood-olive" if j<5 else "lining"')
s=s.replace('profiles,"olive","Head",head,.32,hood_uv,hood_band)',
            'profiles,"hood-olive","Head",head,.29,hood_uv,hood_band)')
s=s.replace('(-9,168),(-9,162),(-16,163),(-18,166)',
            '(-9,168),(-9,164.5),(-16,164),(-18,166)')
s=s.replace('(3,170),(3,162),(-4,163),(-7,165)',
            '(3,170),(3,163.3),(-4,164.6),(-7,165)')
s=s.replace('box("Cape · upper back center",(0,14.7,120),(26,6.5,28),"olive","Chest",shoulder,1.4)',
'''rings("Cape · connecting back drape",[
    [(-14,17,133),(-6,19,134),(7,19,134),(14,17.5,133),
     (12,13.7,133),(6,14.2,133),(-6,14.2,133),(-12,13.7,133)],
    [(-15,20,111),(-6,22.7,111.5),(7,22.3,111.1),(14,20.8,111),
     (13,17.7,111),(6,19.4,111),(-6,19.6,111),(-14,17.5,111)],
    [(-14,30.3,86),(-6,33,84),(7,33.5,84),(14,31.5,87),
     (13,28.5,87),(6,30.9,84),(-6,30.4,84),(-13,28.1,86)]
],"olive","Chest",shoulder,.31)''')
p.write_text(s,encoding="utf8")

p=Path("paint.py")
s=p.read_text(encoding="utf8")
s=s.replace('face = Image.new("RGB",(64,64),"#da9571")',
'''hood = Image.open(OUT/"olive.png").convert("RGB")
for y in range(64):
    # Lower hood folds carry muted olive shadow. Leave the top panels warm.
    band = min(1,max(0,(y-26)/33))
    for x in range(64):
        r,g,b = hood.getpixel((x,y))
        hood.putpixel((x,y),(int(r*(.985-.105*band)),int(g*(1-.068*band)),int(b*(.96-.08*band))))
write("hood-olive",hood)

face = Image.new("RGB",(64,64),"#da9571")''')
s=s.replace('rect((10,17,22,20),"3d2b2b")','rect((10,17,20,20),"392529")')
s=s.replace('rect((20,18,27,21),"332529")','rect((19,19,26,22),"332226")')
s=s.replace('rect((38,18,45,21),"352529")','rect((38,19,45,22),"352326")')
s=s.replace('rect((45,16,54,19),"402b2b")','rect((45,17,54,20),"40292a")')
p.write_text(s,encoding="utf8")

