"""Polish the selected Forager study after comparing the three draft views."""
from pathlib import Path

p=Path("forager.py")
s=p.read_text(encoding="utf8")
def replace(old,new):
    global s
    assert old in s,old
    s=s.replace(old,new,1)

replace('for t,delta in ((.03,0),(.50,1.8 if steps and i in (0,1,4,5) else 0)):',
        '''for t,delta in ((.03,0),(.49,0),(.52,2.65 if steps and i in (0,1,4,5) else 0),
                            (.98,2.65 if steps and i in (0,1,4,5) else 0)):''')
replace('height=z-fall+offset+(lower[i]+delta if steps else 0)',
        'height=z-fall+offset+(lower[i]+delta-max(0,abs(x)-33)*.20 if steps else 0)')
replace('mantle_ring(116.1,27.1,34.0,lift,True)','mantle_ring(116.5,27.1,34.0,lift,True)')
replace('mantle_ring(112.4,28.1,34.3,lift,True)','mantle_ring(112.0,28.6,34.8,lift,True)')
replace('mantle_ring(111.1,25.4,31.8,lift,True)','mantle_ring(110.5,25.4,31.8,lift,True)')
replace('band=lambda j,i:("rust" if j in (0,3) else "lining" if j==4 else "olive")',
        'band=lambda j,i:("rust" if j==0 else "gold" if j==3 else "lining" if j==4 else "olive")')
replace('7.0 if FINAL else','7.0 if FINAL else') if '7.0 if FINAL else' in s else None
replace('8.7,4.1,"darkleather","Chest",chest,.46','7.65,3.8,"darkleather","Chest",chest,.40')
replace('6.95,2.3,"saddle","Chest",chest,.35','6.2,2.0,"saddle","Chest",chest,.31')
replace('(-20,-21.8,84),(23,-19.4,133)','(-20,-20.9,84),(23,-19.4,133)')
replace('(-20,-24,84),(23,-21.6,133)','(-20,-22.8,84),(23,-21.6,133)')
replace('(-20,-25.45,84)','(-20,-24.22,84)')
replace('a=Vector((-20,-24,84))','a=Vector((-20,-22.8,84))')
replace('(-5.3,85.8,2.15,7.8),(5.3,85.8,2.15,7.8))):','(-5.3,85.8,2.15,7.8),(5.3,85.8,2.15,7.8))):')
replace('box("Waist · buckle latch",(0,-22.5,85.6)',
        'box("Waist · buckle latch",(0,-22.65,85.6)')
replace('inputs[1].default_value=.39','inputs[1].default_value=.31')
replace('(0,-.13,1.49),72,(1,.91,.85),1.85','(0,-.13,1.49),63,(1,.89,.81),1.92')
replace('(0,.02,1.47),279,(1,.77,.54),1.23','(0,.02,1.47),268,(1,.77,.54),1.21')
replace('scene.view_settings.exposure=.03','scene.view_settings.exposure=.08')
# Slightly deepen and warm the face's lower center so it remains the focus.
p.write_text(s,encoding="utf8")

p=Path("paint.py")
s=p.read_text(encoding="utf8")
replace('color = rng.choices([1,2,3,4,5], [3,16,50,25,6])[0]',
        'weights = [7,23,39,24,7] if name in ("olive","rust","gold") else [3,16,50,25,6]\n            color = rng.choices([1,2,3,4,5], weights)[0]')
replace('rect((13,36,49,54),"e9a17a")',
        'rect((13,36,49,54),"eba57e")\nrect((10,44,20,52),"e49a76")\nrect((47,44,54,52),"de936e")')
replace('rect((a,25,a+4,29),"a7867b")','rect((a,25,a+4,29),"a78073")')
replace('rect((b-4,25,b,29),"a7867b")','rect((b-4,25,b,29),"a78073")')
p.write_text(s,encoding="utf8")

