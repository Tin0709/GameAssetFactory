"""Layer the Forager's waistcoat, open mantle, arm wraps, and boots."""
from mathutils import Vector
from forms import U,MATERIALS,band,belt_frame,block,loft,mesh,octagon,panel

def make_outfit(chest,cloak,limbs):
    loft("Body · homespun shirt",[
        octagon((0,1,160),84,45,6),
        octagon((0,0,179),85,47,7),
        octagon((0,0,224),95,51,10),
        octagon((0,2,246),75,46,11),
    ],"leather",chest,"Chest",.58)
    panel("Shirt · narrow linen placket",[
        (-6,-26.4,238),(4,-26.4,240),(7,-27.4,222),(7,-27.0,178),
        (10,-26.4,162),(-7,-26.4,161),(-6,-27.1,201)
    ],(0,2,0),"linen",chest,"Chest",.2)

    for sign,side in ((-1,"R"),(1,"L")):
        def side_pts(points):
            return [(sign*x,y,z) for x,y,z in points]

        panel(f"Waistcoat · {side} layered front",side_pts([
            (14,-26,243),(25,-24,245),(43,-21,235),(47,-20,220),
            (42,-22,192),(42,-21,163),(33,-22,159),(18,-26,159),(9,-25,166),
            (12,-25,195),(10,-26,218),(7,-27,226)
        ]),(0,5,0),"leather",chest,"Chest",.6)
        panel(f"Waistcoat · {side} side panel",side_pts([
            (42,-20,237),(49,-7,233),(47,12,218),(43,18,181),(39,14,156),
            (35,4,154),(38,-22,160),(43,-23,193)
        ]),(-sign*5,0,0),"boot",chest,"Chest",.4)
        panel(f"Waistcoat · {side} collar lapel",side_pts([
            (11,-30,242),(7,-29,230),(12,-31,221),(22,-28,225),(24,-24,242)
        ]),(0,4,0),"warmLeather",chest,"Chest",.40)
        panel(f"Waistcoat · {side} lower skirt",side_pts([
            (24,-23,176),(43,-21,172),(47,-21,159),(49,-19,146),(41,-22,143),
            (40,-24,135),(29,-25,136),(23,-25,147)
        ]),(0,5.5,0),"leather",chest,"Hips",.42)
        panel(f"Waistcoat · {side} pocket flap",side_pts([
            (23,-26,207),(37,-24.1,206),(38,-24.8,200),(35,-26,197),(22,-27,198)
        ]),(0,3,0),"warmLeather",chest,"Chest",.37)
        block(f"Waistcoat · {side} pocket stud",(sign*30,-27.2,201.4),(3,1.8,3),"iron",chest,"Chest",.22)
        for k,z in enumerate((184,195,217)):
            block(f"Waistcoat · {side} stud {k}",(sign*11,-27.6,z),(3.3,1.7,3),"boot",chest,"Chest",.28)

    # The diagonal carries the small hip bag. Its corners sit over the fabric.
    a=Vector((-46,-28.5,157))
    b=Vector((48,-22.0,242))
    band("Harness · dark backing",a,b,15,4.7,"boot",chest,"Chest",.30)
    band("Harness · diagonal leather face",a+Vector((0,-2.1,0)),b+Vector((0,-2.1,0)),
         11.8,2.0,"leather",chest,"Chest",.28)
    arm_dir=Vector((b.x-a.x,0,b.z-a.z)).normalized()
    u=Vector((arm_dir.z,0,-arm_dir.x))
    for i in range(23):
        pt=a.lerp(b,(i+1)/25)-u*4.9+Vector((0,-3.4,0))
        block("Harness · seam "+str(i+1),pt,(1.75,.61,.75),"cream",chest,"Chest",.05,(0,-49,0))
    # A small adjustment buckle at the upper chest remains independent of the bag.
    belt_frame("Harness · small buckle",a.lerp(b,.62)+Vector((0,-4.35,0)),u,arm_dir,
               12.2,12.2,2.05,"iron",chest,"Chest")
    loft("Waist · broad belt",[
        octagon((0,-.5,162),94,57,5.8),octagon((0,-.8,178.1),94.5,57.4,6)
    ],"boot",chest,"Hips",.55)
    band("Waist · turned lower edge",(-38,-30,164),(40,-29.8,164),2.2,2.1,
         "leather",chest,"Hips",.19)
    block("Waist · buckle seat",(12,-31,170.7),(22.5,6.6,19.2),"leather",chest,"Hips",.56)
    belt_frame("Waist · square buckle",(12,-35.1,170.7),(1,0,0),(0,0,1),
               17.9,15.5,3.1,"iron",chest,"Hips")
    for i,x in enumerate((-24,-9,27,37)):
        block("Waist · belt keeper "+str(i+1),(x,-30.5,169.5),(6,2.5,15),"warmLeather",chest,"Hips",.4)

    # A single cloak with a folded shoulder and a low, stepped center.
    # It is built around the revealed back of the new concept.
    tabs=[
        (-63,115),(-59,107),(-53,107),(-53,94),(-45,94),(-45,103),
        (-36,103),(-36,112),(-29,112),(-29,98),(-21,98),(-21,86),
        (-13,86),(-13,75),(-7,75),(-7,66),(7,66),(7,76),(17,76),(17,85),
        (24,85),(24,100),(35,100),(35,110),(45,110),(45,99),(54,99),
        (54,109),(60,109),(63,121),
    ]
    verts=[]
    for j,row in enumerate((0,.14,.34,.61,.84,1)):
        for i,(x,z) in enumerate(tabs):
            if j<5:
                end_x=x*.92
                z0=241-abs(x)*.17
                step=row
                z1=z+11 if j==4 else z0+(z-z0)*step
                xx=end_x*(.76+.24*step)+(-1.3 if x<0 else 1.3)*step
                # Stagger close coordinates above each cut in the hem.
                xx+=(i-(len(tabs)-1)/2)*.14*(1-step)
            else:
                xx,z1=x,z
            fold=1.8*((i//2)%3-1)+2.6*max(0,1-abs(x)/34)
            yy=21+15*row+fold+9*row*row*(1-abs(x)/70)+10*(1-row)**2
            verts.append((xx,yy,z1))
    n=len(tabs)
    fs,colors=[],[]
    for j in range(5):
        for i in range(n-1):
            a=j*n+i
            fs.append((a,a+1,a+n+1,a+n))
            side=abs(tabs[i][0])
            colors.append("gold" if j==4 else "mossDark" if side>51 and i%3==0 else "moss")
    # Paint the return in darker olive while retaining the same ochre binding.
    # The front and rear cloth share a sewn perimeter.
    count=len(verts)
    outer=list(fs)
    front=[(x,y-1.65,z) for x,y,z in verts]
    fs.extend(tuple(j+count for j in reversed(face)) for face in outer)
    inner=["gold" if color=="gold" else "mossDark" for color in colors]
    colors+=inner
    incidence={}
    for face in outer:
        for a,b in zip(face,face[1:]+face[:1]):
            key=frozenset((a,b))
            incidence.setdefault(key,[]).append((a,b))
    for boundary in incidence.values():
        if len(boundary)!=1:
            continue
        a,b=boundary[0]
        fs.append((b,a,a+count,b+count))
        colors.append("gold" if min(a,b)>=5*n else "lining")
    back=mesh("Cape · continuous stepped back",verts+front,fs,colors,cloak,"Chest",0,
              uv=lambda p,a,n,c:((p[0]+63)/129,(p[2]-66)/174))
    back.shape_key_add(name="Resting cloak")
    drape=back.shape_key_add(name="Hero · outward sweep")
    for v in drape.data:
        x,y,z=v.co/U
        fall=max(0,min(1,(230-z)/117))
        near=max(0,min(1,(45-x)/85))
        v.co.x-=U*34*fall*near
        v.co.y+=U*26*fall*(.5+.5*near)
        v.co.z-=U*9*fall*near
    drape.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"

    # Rounded cuboid shoulders with layered fabric. The outer line and
    # stepped hem flare toward the outside of the arm as in the figures.
    for sign,side in ((-1,"R"),(1,"L")):
        arm="UpperArm."+side
        fore="ForeArm."+side
        def x(v): return sign*v

        loft(side+" · short sleeve",[
            octagon((x(54),0,212),26,31,3.2),
            octagon((x(51),0,222),25,28,4),
            octagon((x(48),2,229),20.5,23.0,3.5)
        ],"linen",limbs,arm,.49)
        band(side+" · upper arm",(x(50),0,228),(x(61),-1,195),
             23,26,"skin",limbs,arm,.55)
        band(side+" · forearm",(x(60),-1,200),(x(74),-5,132),22,24,
             "skin",limbs,fore,.51)
        w0,w1=Vector((x(63),-2,190)),Vector((x(70),-4.5,152))
        for k in range(5):
            a=w0.lerp(w1,k/5)
            b=w0.lerp(w1,(k+1)/5)+Vector((0,0,.22))
            band(side+f" · linen wrap {k+1}",a,b,25.2+(.9 if k==1 else 0),28.5,
                 "linen",limbs,fore,.30)
        band(side+" · leather glove",(x(70),-4.5,154),(x(76),-6,130),
             25,27.5,"boot",limbs,fore,.5)
        band(side+" · cuff top seam",(x(69.6),-4.7,156),(x(71.2),-5,149),
             26.5,29.2,"leather",limbs,fore,.34)
        band(side+" · hand and fingers",(x(76),-6,134),(x(78.5),-6.5,124),
             23.5,24.5,"skin",limbs,fore,.63)
        for j,u in enumerate((-6,0,6),1):
            band(side+f" · hand crease {j}",(x(76)+u,-19.2,132),(x(78)+u,-18.7,126),
                 .48,.45,"warmLeather",limbs,fore,0)
        block(side+" · thumb",(x(67.5),-12.2,134),(7,13,10),"skin",limbs,fore,.64,(0,sign*10,-9))

        def cuff(z,w,d,steps=0):
            ring=octagon((x(52),.3,z),w,d,6)
            pts=[]
            for k,a in enumerate(ring):
                b=ring[(k+1)%8]
                for t,h in ((.015,0),(.46,0),(.49,steps),(.98,steps)):
                    i,j,_=Vector(a).lerp(Vector(b),t)
                    slope=(abs(i)-42)*.58 if abs(i)>42 else -.24*(42-abs(i))
                    drop=steps*(.75 if j>11 else 0)
                    pts.append((i,j,z-slope-drop+h))
            return pts
        lift=3 if sign>0 else 0
        layers=[cuff(244+lift,28,37),cuff(240+lift,34,42),cuff(228+lift,40,48),
                cuff(221+lift,42.5,50,4.3),cuff(214+lift,45,50,4.3),cuff(212.4+lift,40.5,45,4.3)]
        mantle=loft(side+" · cloth shoulder cape",layers,"moss",cloak,arm,.38,
             lambda row,p: "rust" if row==0 else "gold" if row==3 else "lining" if row==4 else "moss")

        if sign<0:
            u=Vector((1,0,-.18))
            v=Vector((.14,0,1))
            center=Vector((-55,-88,223))
            for i,(a,b) in enumerate(((0,0),(-1,0),(1,0),(0,-1),(0,1))):
                mid=center+3.3*(a*u+b*v)
                pts=[]
                for du,dv in ((-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)):
                    ray=mid+3.3*(du*u+dv*v)
                    found,q,norm,_=mantle.ray_cast(ray*U,Vector((0,1,0)))
                    if found:
                        pts.append(tuple(q/U+norm*.55))
                if len(pts)==4:
                    panel(f"Shoulder · cream mending {i+1}",pts,(0,1.2,0),"cream",cloak,arm,.1)

    loft("Trousers · upper block",[
        octagon((0,4,124),88,45,5),octagon((0,2,167),91,47,6)
    ],"coal",limbs,"Hips",.52)
    for sign,side in ((-1,"R"),(1,"L")):
        leg="Leg."+side
        x=sign*28.8
        loft(side+" · trouser leg",[
            octagon((x,4,83),42,39,3),
            octagon((x,5,117),43,41,3),
            octagon((x*.93,3,150),47,43,4),
        ],"coal",limbs,leg,.54)
        panel(side+" · outer olive trouser patch",[
            (x-sign*11,-17,142),(x+sign*21,-15,142),(x+sign*20,-15,106),
            (x+sign*11,-18,104),(x-sign*10,-18,108)
        ],(0,2.8,0),"moss",limbs,leg,.48)
        if sign>0:
            for k,(a,b) in enumerate(((0,0),(-1,0),(1,0),(0,-1),(0,1))):
                block(f"Trousers · repaired patch {k+1}",(x+6+5.1*a,-18.3,116+5.1*b),(5.3,2.1,5.4),
                      "cream",limbs,leg,.06)
        loft(side+" · exposed knee",[
            octagon((x,4,69),43,39.5,3.9),octagon((x,4,91),42,39.5,3.8)
        ],"skin",limbs,leg,.56)
        loft(side+" · boot shaft",[
            octagon((x,4.3,11),44,48,4.0),
            octagon((x,5,57),44.5,43,3.4),
            octagon((x,5,73),46,44.6,3.6)
        ],"boot",limbs,leg,.65)
        loft(side+" · heavy sole",[
            octagon((x,-10,0),49,66,4.7),octagon((x,-10,9),49,66.2,4.9)
        ],"boot",limbs,leg,.63)
        loft(side+" · welt",[
            octagon((x,-11,8.2),47.8,65,4.5),octagon((x,-11,11.8),47.4,64.8,4.5)
        ],"leather",limbs,leg,.35)
        loft(side+" · toe of boot",[
            octagon((x,-12,11),47,64,4.1),
            octagon((x,-14,20),47,61.5,5.4),
            octagon((x,-10.2,28),43,49,6.0),
        ],"warmLeather",limbs,leg,.68)
        for z,w,d,h in ((63,48.5,48,10.5),(42,46.8,47,8.2)):
            loft(side+f" · boot wrap {z}",[
                octagon((x,4.7,z-h/2),w,d,3.65),octagon((x,4.7,z+h/2),w,d,3.65),
            ],"leather",limbs,leg,.58)
        for z,y in ((65,-9),(43,-12)):
            block(side+f" · metal boot clip {z}",(x+sign*25.3,y,z),(4.8,13.0,11.7),
                  "iron",limbs,leg,.60,(0,sign*1,0))
            block(side+f" · strap rivet {z}",(x-sign*9,-20.5,z),(9.3,2.8,6.0),
                  "iron",limbs,leg,.41)


