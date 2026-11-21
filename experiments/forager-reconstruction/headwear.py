"""The Forager head and hood, traced as angular cloth panels."""
import math
from mathutils import Vector
from forms import MATERIALS,U,band,block,loft,mesh,octagon,panel

def make_head(head,neck):
    # Front and cheek contour pairs follow the new concept. The inner
    # contour preserves distinct steps at the brow and at each temple.
    half=[
        (0,348,0,330),(11,348,11,330),(20,348,11,328),
        (30,348,21,328),(37,347,21,322),(44,343,28,322),
        (48,337,28,315),(50,331,34,315),(52,324,34,306),
        (54,317,39,306),(56,310,39,296),(57.5,302,44,296),
        (59,294,44,286),(61,285,47,286),(63,276,47,275),
        (63.5,269,49,271),(56,257,44,263),
    ]
    shape=[(-a,b,-c,d) for a,b,c,d in reversed(half[1:])]+half
    n=len(shape)
    pts=[]
    for row in range(7):
        for x,z,i,j in shape:
            q=abs(x)
            edge=z<264
            y_f=-46.9+.22*max(0,296-j)+.08*max(0,j-324)
            if row==0:
                p=(i,y_f,j)
            elif row==1:
                p=(i*.37+x*.63,y_f-.1,j*.37+z*.63)
            elif row==2:
                p=(x,y_f+6.2,z)
            elif row==3:
                p=(x*1.015,-21+.026*(z-305),z+1.25)
            elif row==4:
                ridge=max(0,1-abs(z-296)/35)
                p=(x*(.984-.021*ridge),5,z+2.1)
            elif row==5:
                p=(x*.90,23+.065*(305-z),z-2.1)
            else:
                p=(x*.735,36+.05*(298-z),305+(z-305)*.86)
            if edge:
                sign=1 if x>0 else -1
                p=(sign*(51,54,59,58,56,50,43)[row],
                   (-24,-24,-20,-10,9,25,36)[row],(254,253.8,254.9,252,251,252,257)[row])
            pts.append(tuple(p))
    faces=[]
    names=[]
    for row in range(6):
        for i in range(n-1):
            k=row*n+i
            faces.append((k,k+1,k+n+1,k+n))
            if row==0 and i not in (0,n-2):
                names.append("gold")
            elif i in (0,n-2) and row>0:
                names.append("mossDark")
            else:
                names.append("moss")
    faces.append(tuple(range(6*n,7*n)))
    names.append("moss")
    def hood_uv(p,axis,normal,mat):
        x,y,z=p
        if axis==0:
            return ((y+50)/89,(z-251)/101)
        if axis==2:
            return ((x+67)/135,(y+49)/90)
        return ((x+65)/129,(z-251)/99)
    hood=mesh("Hood · open cloth shell",pts,faces,names,head,"Head",0,hood_uv,
              normal_tip=(2*(n-1)+n//2,2,1))
    hood.data.materials.append(MATERIALS["lining"])
    lining=hood.modifiers.new("Cloth lining","SOLIDIFY")
    lining.thickness=1.25*U
    lining.offset=-1
    lining.use_even_offset=True
    lining.use_quality_normals=True
    lining.material_offset=3
    lining.material_offset_rim=3
    bevel=hood.modifiers.new("Cloth crease edges","BEVEL")
    bevel.width=.56*U
    bevel.segments=1
    bevel.angle_limit=.74

    # Keep the face inside the cloth and the lower olive band under the mouth.
    def face_uv(p,axis,normal,mat):
        x,y,z=p
        if mat=="face":
            return ((x+28)/59,(z-260)/63)
        return ((y+35)/55,(z-258)/65)
    loft("Head · face",[
        octagon((1,-6,259),60,52.2,4),
        octagon((1,-6.5,317.5),65,53,4),
        octagon((1,-5.0,322),59,49,4.8),
    ],"skin",head,"Head",.29,lambda r,i:"face" if r==0 and i==0 else "skin",face_uv)

    hair=[
        ([(-33,318),(-22,322),(-21,305),(-24,299),(-25,282),(-33,278),(-37,288)],-35),
        ([(-24,324),(-5,326),(-7,314),(-11,314),(-11,301),(-17,300),(-17,297),(-29,300)],-38),
        ([(-9,325),(12,327),(13,317),(9,312),(7,312),(5,299),(-5,300),(-12,306)],-38),
        ([(11,325),(26,323),(29,311),(27,301),(22,301),(22,306),(15,306),(12,314)],-36.8),
        ([(25,319),(33,314),(36,299),(37,278),(29,276),(27,287),(25,296)],-34.8),
    ]
    for i,(outline,y) in enumerate(hair,1):
        panel(f"Fringe · lock {i}",[(x,y+.065*x+.15*max(0,z-313),z) for x,z in outline],
              (0,9,0),"hair",head,"Head",.59)
    panel("Hair behind braid",[
        (-37,-35,300),(-25,-40,298),(-25,-40,284),(-23,-34,268),(-31,-32,262),(-39,-33,278)
    ],(0,15,0),"hair",head,"Head",.58)

    braid=[
        ((-33,-34,285),(-31,-40,265),19,15),
        ((-36,-39,275),(-26,-40,260),17.5,13),
        ((-31,-41,263),(-23,-43,249),16.8,14),
        ((-29,-42,251),(-21,-42,236),15.2,12),
        ((-24,-42,238),(-21,-40,224),13.5,11.2),
        ((-21,-40,227),(-20,-37,217),11.2,9.0),
    ]
    for i,(a,b,w,d) in enumerate(braid):
        bone="Head" if i<2 else "Chest"
        band(f"Braid · broad lock {i+1}",a,b,w,d,"hair",head,bone,.54,(1.05,.78))
    band("Braid · light cloth binding",(-24,-43,239),(-22,-42,233),15.6,13.5,"linen",head,"Chest",.32)

    # Small crossed stitches lie on the outer hood panel rather than in space.
    def mend(label,y,z,dy,dz):
        origin=Vector((-110*U,y*U,z*U))
        direct=Vector((1,0,0))
        pts=[]
        for u,v in ((-1,-1),(1,-1),(1,1),(-1,1)):
            hit,p,norm,_=hood.ray_cast(origin+Vector((0,u*dy*U,v*dz*U)),direct)
            if hit:
                pts.append(tuple(p/U+norm*.65))
        if len(pts)==4:
            panel(label,pts,(1.2,0,0),"cream",head,"Head",.12)
    for i,(y,z,dy,dz) in enumerate(((-5,312.6,6.25,1.65),(-5,318.4,6.25,1.65),
                                   (-7.6,315.5,1.65,6.1),(-2.4,315,1.65,6.1))):
        mend(f"Hood · repair stitch {i+1}",y,z,dy,dz)

    # White feather and rust ribbon pinned behind the temple.
    block("Charm · clasp",(-53,21,326),(9,11,8.2),"warmLeather",head,"Head",.57,(13,-8,12))
    block("Charm · pale tie",(-56,19,324),(7.2,8.5,5.2),"linen",head,"Head",.40,(12,-12,11))
    def feather(label,outline,palette,ribbon=False):
        coords=[]
        for y,z in outline:
            drop=323-z
            coords.append((-57-.215*drop+.045*(y-21),y,z))
        if ribbon:
            panel(label,coords,(1.5,0,0),palette,head,"Head",.17)
        else:
            mid=Vector(tuple(sum(coords[k][axis] for k in range(len(coords)))/len(coords) for axis in range(3)))
            mid.x-=2.25
            pts=coords+[tuple(mid)]+[(x+1.55,y,z) for x,y,z in coords]
            n=len(coords)
            faces=[(j,(j+1)%n,n) for j in range(n)]
            faces.append(tuple(range(n+1,2*n+1)))
            faces.extend((j,(j+1)%n,(j+1)%n+n+1,j+n+1) for j in range(n))
            vals=[palette if j%4 else "linen" for j in range(n)]+[palette]*(n+1)
            mesh(label,pts,faces,vals,head,"Head",.17)
    feather("Charm · ivory feather",[(22,324),(17,317),(20,312),(17,304),(21,299),
            (19,288),(24,285),(26,277),(31,282),(31,287),(37,294),(36,303),(42,309),(35,321)],"cream")
    feather("Charm · rust ribbon",[(22,325),(30,323),(38,318),(58,312),(57,307),
            (49,307),(47,302),(36,306),(28,315)],"rust",True)
    band("Charm · feather spine",(-58,23,322),(-66,29,282),2.35,1.55,"cream",head,"Head",.13)

    block("Neck", (0,-2,254),(28,32,24),"skin",neck,"Neck",.9)
    def scarf(z,w,d,y,tilt):
        return [(x,a,z+tilt*x/w+.042*a) for x,a,_ in octagon((0,y,z),w,d,9)]
    loft("Scarf · olive chin fold",[
        scarf(252,89,64,-8,-1.8),scarf(256,92,72,-9,-2.4),
        scarf(264,91,70,-9,-3.2),scarf(266,84,65,-9,-2.4)
    ],"lining",neck,"Head",.48)
    loft("Scarf · terracotta neck wrap",[
        scarf(236,89,68,-2,-1.0),scarf(241.5,104,76,-3,-4.1),
        scarf(253.5,102,75,-3,-5.4),scarf(258.4,92,69,-3,-4.4)
    ],"rust",neck,"Neck",.65)
    panel("Scarf · top fold",[
        (-45,-31,252),(-29,-41,253),(3,-45,246),(36,-36,241),(44,-32,241),
        (34,-38,233),(19,-42,234),(-8,-46,241),(-27,-43,246)
    ],(0,5,0),"rust",neck,"Neck",.64)
    panel("Scarf · end at shoulder",[
        (34,-29,247),(48,-27,242),(53,-22,232),(58,-19,222),(51,-21,225),
        (44,-26,226),(38,-31,232)
    ],(0,5,0),"rust",neck,"Neck",.53)
    return hood


