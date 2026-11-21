"""Apply the fitting decisions from the first front, profile, and hero renders."""
from pathlib import Path

p=Path("forager.py")
s=p.read_text(encoding="utf-8-sig")
def replace(old,new):
    global s
    assert old in s,old
    s=s.replace(old,new,1)

replace('profiles=[crown_back,rear_turn,upper_side,front_seam,front_rim,inner_rim,lining,lining_end]',
'''binding_edge=[tuple(Vector(a).lerp(Vector(b),.39)) for a,b in zip(front_rim,inner_rim)]
profiles=[crown_back,rear_turn,upper_side,front_seam,front_rim,binding_edge,inner_rim,lining,lining_end]''')
replace('    if j==4:', '    if j==5:')
replace('return "olive" if j<4 else "lining"','return "olive" if j<5 else "lining"')
replace('octagon(0,-2.8,137.2,42.5,43.7,2)','octagon(0,-2.3,137.2,40.8,43.0,2)')
replace('octagon(0,-2.8,174.9,43.8,43.7,2)','octagon(0,-2.4,174.9,42.4,43.0,2)')
replace('return ((x+21)/42,(z-137)/38)','return ((x+19.4)/38.8,(z-137)/38)')
replace('collar(141.3,54.5,45.8,-7,-1.1),','collar(140.9,54.5,45.1,-6.9,-1.1),')
replace('collar(142.4,51,40,-7.2,-1.3)','collar(141.9,51,40,-7.1,-1.3)')
replace('a,b,w,d,"hair","Head" if i<2 else "Chest",head,.66',
        'a,b,w*.885,d*.9,"hair","Head" if i<2 else "Chest",head,.46')
replace('11.3,10.25,"linen"', '10.5,9.6,"linen"')
replace('cross("Hood · linen repair",(-33.55,-10.7,166.2),(0,-1,0),(.16,0,.98),2.9,"thread","Head",head)',
'''def projected_mark(label, support, origin, u, v, heading, pitch, col, bone, group):
    origin,u,v,heading = map(Vector,(origin,u,v,heading))
    for i,(a,b) in enumerate(((0,0),(-1,0),(1,0),(0,-1),(0,1))):
        center=origin+pitch*(a*u+b*v)
        points=[]
        for du,dv in ((-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)):
            test=center+pitch*(du*u+dv*v)
            hit,location,normal,_=support.ray_cast(test*UNIT,heading)
            if hit:
                points.append(tuple(location/UNIT+normal*.28))
        if len(points)==4:
            panel(label+f" {i+1}",points,tuple(heading*.57),col,bone,group,.045)

projected_mark("Hood · linen repair",hood,(-92,-9,166.6),(0,-.86,.5),
               (0,.5,.86),(1,0,0),3.05,"thread","Head",head)''')
replace('((107,20.5,23.5,1.6),(119,22,25,2),\n           (130.7,21.3,24.8,2.1),(134,17.2,19.1,2.4))',
        '((107,18.6,21.9,1.6),(119,19.4,22.1,2),(126.8,16.2,19.7,2.1),(129.5,13.6,17.8,2.4))')
start=s.index('    # The near repair shoulder')
end=s.index('for sign,side in ((-1,"R"),(1,"L")):\n    j=rig.pose',start)
s=s[:start]+'''    # Cut a short cloak sleeve from the neckline to the upper arm. The
    # olive and rust share topology, so the square hem has no overlay gaps.
    def mantle_ring(z,w,d,offset=0,steps=False):
        regular=octagon(sign*32.2,0,z,w,d,min(5.4,w*.21))
        points=[]
        lower=(0,-1.8,-3.7,-5.1,-5.1,-3.4,-2.0,-.6)
        if sign>0:
            lower=tuple(reversed(lower))
        for i,a in enumerate(regular):
            b=regular[(i+1)%len(regular)]
            for t,delta in ((.03,0),(.50,1.8 if steps and i in (0,1,4,5) else 0)):
                x,y,_=Vector(a).lerp(Vector(b),t)
                fall=max(0,(abs(x)-25))*.23
                height=z-fall+offset+(lower[i]+delta if steps else 0)
                points.append((x,y,height))
        return points
    lift=1.9 if side=="L" else 0
    sewn=[mantle_ring(134,18.6,27,lift),
          mantle_ring(131.4,21.8,29.8,lift),
          mantle_ring(127.5,25.8,33.8,lift),
          mantle_ring(116.1,27.1,34.0,lift,True),
          mantle_ring(112.4,28.1,34.3,lift,True),
          mantle_ring(111.1,25.4,31.8,lift,True)]
    cloth=rings(f"{side} · tailored shoulder cloak",sewn,"olive",arm,shoulder,.21,
                band=lambda j,i:("rust" if j in (0,3) else "lining" if j==4 else "olive"))
    if side=="R":
        projected_mark("Right shoulder · visible mending",cloth,(-34.7,-48,118.9),
                       (.98,0,-.10),(.1,0,.98),(0,1,0),2.65,"thread",arm,shoulder)

'''+s[end:]
replace('(-2.2,-3.0,3.57),(0,-.03,1.36),259,(1,.848,.717),2.5',
        '(-2.35,-2.7,3.77),(0,-.03,1.40),222,(1,.835,.696),1.78')
replace('(.64,-2.90,1.78),(0,-.13,1.49),63,(1,.91,.86),2.18',
        '(.42,-2.4,1.78),(0,-.13,1.49),72,(1,.91,.85),1.85')
replace('(-1.15,1.8,3.24),(0,.02,1.46),221,(1,.78,.58),1.42',
        '(-1.15,1.8,3.42),(0,.02,1.47),279,(1,.77,.54),1.23')
replace('scene.view_settings.exposure=.30','scene.view_settings.exposure=.03')
p.write_text(s,encoding="utf8")

p=Path("paint.py")
s=p.read_text(encoding="utf-8-sig")
replace('"47432f","514a33","5c5438","695f3d","706543","7d714b","8a7b4e"',
        '"373724","413f2b","4d482e","574f33","635939","6b6140","7a6e45"')
replace('"96622d","ad773a","be8a47","cb9951","d5a35a","d9ac68","e0b774"',
        '"824c20","9a642f","aa7537","b5803a","c48e47","d19b52","d9a860"')
replace('"2c2024","35262b","3b2a30","46313a","50383f","5b3d43","69484b"',
        '"231819","2b2021","332527","3c2a2c","453031","503536","5d3e3e"')
replace('"713923","884626","9a502b","ab5d33","b86738","be7342","cd8251"',
        '"682c1a","793622","8b3b24","9d4729","ac502e","b75530","c36339"')
replace('face = Image.new("RGB",(64,64),"#d29a7b")','face = Image.new("RGB",(64,64),"#da9571")')
for old,new in (("e2a384","e9a17a"),("ebd0be","eed3bd"),("33242a","2c2024"),
                ("503235","472e30"),("b17b62","bb785a"),("d1997b","dd956f"),("e3a787","eda67f")):
    s=s.replace(old,new)
replace('rect((a,22,b,43)','rect((a,23,b,42)')
replace('rect((a,25,b,43)','rect((a,26,b,42)')
replace('rect((a+5,23,b,43)','rect((a+5,24,b,42)')
replace('rect((a,23,b-5,43)','rect((a,24,b-5,42)')
replace('rect((a+5,37,b,43)','rect((a+5,37,b,42)')
replace('rect((a,37,b-5,43)','rect((a,37,b-5,42)')
p.write_text(s,encoding="utf8")

