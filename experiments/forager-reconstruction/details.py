"""Visible clothing accessories and the separate stylized hero props."""
from mathutils import Vector
from forms import U,band,belt_frame,block,loft,mesh,octagon,panel

def herbs(name,origin,col,bone,flowers=True,scale=1):
    origin=Vector(origin)
    def p(x,y,z):
        return tuple(origin+scale*Vector((x,y,z)))
    band(name+" · hanging loop",p(-2,0,1),p(-2,-.5,-17),
         4.5*scale,4.0*scale,"linen",col,bone,.26)
    band(name+" · loop return",p(3,0,-3),p(3,-2,-16),
         3.2*scale,3.55*scale,"cream",col,bone,.16)
    block(name+" · knot",p(1,-2,-14),tuple(a*scale for a in (9,6,5)),"cream",col,bone,.42,
          (0,-8,21))
    for i,(x,y,z) in enumerate(((-8,-2,-31),(-12,2,-27),(-4,-4,-36),
                                 (5,-2,-31),(11,1,-27),(2,-1,-37),(12,-4,-34))):
        band(name+f" · leaf stem {i}",p(1,0,-13),p(x,y,z),2.0*scale,1.25*scale,"mossDark",col,bone,.1)
        panel(name+f" · oak leaf {i}",[
            p(x*.33,y,z+14),p(x+3,y-1,z+9),p(x+2,y-2,z+3),p(x,y-1,z),p(x-3,y,z+6)
        ],(0,2.55*scale,1.2*scale),"leaf",col,bone,.14)
    if flowers:
        for i,(x,y,z) in enumerate(((-3,-3,-39),(6,-5,-32),(10,-2,-42),(-1,-4,-48))):
            for j,(a,b) in enumerate(((-1,0),(0,0),(1,0),(0,-1))):
                center=p(x+3.0*a,y+(j%2)*.4,z+3.0*b)
                block(name+f" · violet petal {i}.{j}",center,tuple(w*scale for w in (3.35,3.35,3.2)),
                      "purple",col,bone,.13,(0,9*(i%3-1),0))

def torso_props(col):
    bag="Hips"
    outline=[(-59,-42,177),(-58,-42,151),(-54,-43,139),(-49,-45,137),
             (-26,-45,138),(-19,-43,142),(-18,-42,168),(-22,-42,179)]
    panel("Sling bag · leather case",outline,(0,15,0),"leather",col,bag,.9)
    panel("Sling bag · flap",[
        (-59,-42,180),(-19,-44,181),(-18,-46,165),(-24,-48,158),(-52,-47,155),(-60,-44,158)
    ],(0,4.0,0),"warmLeather",col,bag,.67)
    panel("Sling bag · inner hem",[
        (-53,-45,153),(-25,-46,156),(-27,-47,144),(-54,-46,141)
    ],(0,2.5,0),"leather",col,bag,.42)
    block("Sling bag · latch strap",(-39,-47.5,150),(10.5,4.9,11),"warmLeather",col,bag,.43)
    block("Sling bag · latch pin",(-39,-51,151),(5.6,2,4.0),"iron",col,bag,.31)
    panel("Sling bag · left leaf emblem",[
        (-41,-48.4,163),(-47,-46.6,164),(-50,-46.1,169),
        (-45,-47.3,169),(-40,-48.2,166)
    ],(0,.85,0),"gold",col,bag,.15)
    panel("Sling bag · right leaf emblem",[
        (-42,-48,162),(-39,-48.8,167),(-33,-48.5,171),
        (-31,-47.9,170),(-34,-48.5,164),(-38,-49,161)
    ],(0,.85,0),"gold",col,bag,.15)
    band("Sling bag · central stem",(-40,-48.9,158),(-40,-49.2,166),1.18,1.0,"gold",col,bag,.12)
    herbs("Waist herb sprig",(-5,-31.7,167),col,"Hips",True,.90)
    block("Far hip · small pouch",(44,-16,165),(15,14,21),"leather",col,"Hips",.75,(0,-11,-5))
    block("Far hip · pouch flap",(43,-24,169),(14.2,3.3,13),"warmLeather",col,"Hips",.44,(0,-8,-5))

def staff_and_lamp(col,grip):
    gx,gy,gz=grip
    def p(z,dx=0,dy=0):
        return (gx+(z-gz)*.075+dx,gy+(z-gz)*.035+dy,z)

    band("Staff prop · dark wood",p(.6),p(308),9.6,10.2,"wood",col,None,.55)
    band("Staff prop · raised wood edge",p(18,-2,-3.5),p(295,-2,-4.4),2.3,1.9,"warmLeather",col,None,.19)
    for i,(z,width,h,mat) in enumerate((
        (18,12,8,"leather"),(69,11.8,6.8,"linen"),(86,12.7,7.5,"linen"),
        (104,12.6,9.1,"leather"),(137,14.7,8.8,"leather"),(179,13.3,11.2,"wood"),
        (198,14.6,8.8,"warmLeather"),(247,14.6,12.3,"linen"),(268,16.4,8.9,"leather"),
        (290,17.3,10,"warmLeather"),(304,25.2,9.2,"warmLeather"),
    )):
        band(f"Staff prop · wrap {i+1}",p(z-h/2),p(z+h/2),width,width*.92,mat,col,None,.43)
    for i,(z,dx,dy) in enumerate(((303,8,-2.5),(304,-7,1),(291,6,2),(281,-5,1))):
        block("Staff prop · wood collar "+str(i+1),p(z,dx,dy),(13,12,8.1),"warmLeather",col,None,.67,(7,-9,14))

    loft("Staff prop · faceted decorative head",[
        octagon(p(304),14.2,10.1,3),
        octagon(p(321,1),23.3,14.4,4.3),
        octagon(p(335,3),15.3,10.8,3.2),
        octagon(p(349,4),1.5,2.15,.6),
    ],"stone",col,None,.36)
    panel("Staff prop · hanging red tie",[
        p(111,1,-6),p(112,6,-6),p(99,7,-8),p(83,10,-8),p(63,10,-9),
        p(62,4,-8),p(75,3,-7)
    ],(0,1.45,0),"rust",col,None,.26)

    # Colored glass and a layered square frame describe the whole lantern.
    lx,ly,lz=p(237,25,-2)
    cx=Vector((lx,ly,lz))
    def l(x,y,z):
        return cx+Vector((x,y,z))
    band("Lantern · support arm",p(278,1,-2),l(-2,0,34),6.3,5.3,"wood",col,None,.47)
    for a,b in (((-4,0,32),(-7,0,25)),((-7,0,25),(-5,0,20)),((-5,0,20),(4,0,20)),
                ((4,0,20),(7,0,25)),((7,0,25),(4,0,32)),((4,0,32),(-4,0,32))):
        band("Lantern · angular loop",l(*a),l(*b),2.6,2.45,"warmLeather",col,None,.17)
    loft("Lantern · roof",[
        octagon(l(0,0,11),24.0,20.8,3.0),octagon(l(0,0,16),23.5,20.1,3.0),
        octagon(l(0,0,20),14.3,13.0,2.5),
    ],"boot",col,None,.41)
    loft("Lantern · lower frame",[
        octagon(l(0,0,-16),25.1,21.2,3.36),octagon(l(0,0,-10),24.1,20.5,3.2),
        octagon(l(0,0,-8),20.9,18.7,2.5),
    ],"warmLeather",col,None,.47)
    block("Lantern · honey glass body",l(0,0,.25),(19.3,16.2,23.2),"amber",col,None,1.05)
    block("Lantern · glowing front panel",l(1,-8.45,0),(11.85,.9,14.7),"flame",col,None,.31)
    block("Lantern · glowing side panel",l(-9.9,-.8,.5),(.8,10.4,15.6),"flame",col,None,.29)
    for i,(x,y) in enumerate(((-10,-9),(10,-9),(10,9),(-10,9))):
        block(f"Lantern · dark frame corner {i+1}",l(x,y,0),(3.5,3.5,23.7),"boot",col,None,.43)
    herbs("Staff herb sprig",p(269,8,-14),col,None,False,.69)
    return tuple(l(0,-4,2))

