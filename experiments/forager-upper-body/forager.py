"""Assemble and light the Forager's editable upper-body study in Blender."""
from pathlib import Path
from math import radians, sin, cos
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parent
SHOWCASE=Path(sys.argv[-3])
OUT=Path(sys.argv[-2])
PASS=sys.argv[-1]
CLAY=PASS=="clay"
FINAL=PASS=="final"
UNIT=.01

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.name="The Forager · Upper-body study"
scene.unit_settings.system="METRIC"
scene["Reference"] = "The Forager | concept sheet supplied by the user"
scene["Study"] = "Upper-body clothing and hair on the approved Minecraft rig"
scene["Rig source"] = "Animation_Showcase.blend · Showcase_Player_Rig"

def collection(label,parent=scene.collection):
    c=bpy.data.collections.new(label)
    parent.children.link(c)
    return c

asset=collection("The Forager")
head=collection("Head and hood",asset)
chest=collection("Scarf and waistcoat",asset)
shoulder=collection("Shoulders and cape",asset)
studio=collection("Review studio")

with bpy.data.libraries.load(str(SHOWCASE),link=False) as (source,target):
    assert "Showcase_Player_Rig" in source.objects
    target.objects=["Showcase_Player_Rig"]
rig=target.objects[0]
asset.objects.link(rig)
rig.name="The Forager | Minecraft rig"
rig.animation_data_clear()
for con in list(rig.constraints):
    rig.constraints.remove(con)
for pose in rig.pose.bones:
    for con in list(pose.constraints):
        pose.constraints.remove(con)
    pose.matrix_basis=Matrix.Identity(4)
rig.parent=None
rig.matrix_world=Matrix.Identity(4)
rig.hide_set(True)
rig.show_in_front=True

def make_material(name,color,rough=.86,metal=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    surface=m.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value=(*color,1)
    surface.inputs["Roughness"].default_value=rough
    surface.inputs["Metallic"].default_value=metal
    surface.inputs["Specular IOR Level"].default_value=.26
    return m,surface

materials={}
clay,_=make_material("MAT · Warm gray clay",(.32,.28,.24))
for name,display,rough in (
    ("olive",(.37,.33,.19),.92),("hood-olive",(.36,.34,.19),.92),("gold",(.72,.50,.23),.86),
    ("lining",(.21,.19,.12),.95),("hair",(.20,.13,.14),.76),
    ("rust",(.55,.24,.115),.9),("saddle",(.39,.22,.15),.84),
    ("darkleather",(.25,.13,.1),.83),("linen",(.65,.50,.34),.96),
    ("skin",(.70,.43,.31),.82),("metal",(.55,.48,.43),.39),
    ("thread",(.82,.63,.40),.91),("face",(.70,.43,.31),.83),
):
    m,bsdf=make_material("MAT · "+name,display,rough,int(name=="metal"))
    tex=m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(str(ROOT/"private"/"textures"/f"{name}.png"))
    tex.image.pack()
    tex.interpolation="Closest"
    tex.extension="REPEAT" if name!="face" else "EXTEND"
    tex.location=(-350,70)
    m.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    materials[name]=m

def mesh(label,points,polys,colors,bone,group,bevel=0,uv=None):
    data=bpy.data.meshes.new("GEO · "+label)
    data.from_pydata([Vector(p)*UNIT for p in points],[],polys)
    bm=bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    data.update()

    selectable=list(dict.fromkeys(colors))
    for col in selectable:
        data.materials.append(clay if CLAY else materials[col])
    uv_coord=data.uv_layers.new(name="Paint")
    for face in data.polygons:
        col=colors[face.index]
        face.material_index=selectable.index(col)
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        for l in face.loop_indices:
            point=points[data.loops[l].vertex_index]
            if uv:
                coords=uv(point,face,axis,col)
            else:
                a,b=((1,2),(0,2),(0,1))[axis]
                coords=(point[a]/73,point[b]/73)
            uv_coord.data[l].uv=coords

    obj=bpy.data.objects.new(label,data)
    group.objects.link(obj)
    if bone:
        parent=rig.data.bones[bone]
        obj.parent=rig
        obj.parent_type="BONE"
        obj.parent_bone=bone
        obj.matrix_parent_inverse=(parent.matrix_local@Matrix.Translation((0,parent.length,0))).inverted()
    if bevel:
        mod=obj.modifiers.new("Edge stitching and wear","BEVEL")
        mod.width=bevel*UNIT
        mod.segments=1
        mod.limit_method="ANGLE"
        mod.angle_limit=radians(27)
        mod.affect="EDGES"
    return obj

def rings(label,profiles,color,bone,group,bevel=0,uv=None,band=None,caps=True):
    n=len(profiles[0])
    assert all(len(r)==n for r in profiles)
    pts=[p for ring in profiles for p in ring]
    faces,cols=[],[]
    for j in range(len(profiles)-1):
        for i in range(n):
            a=j*n+i
            b=j*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
            cols.append(band(j,i) if band else color)
    if caps:
        faces.extend([tuple(range(n)),tuple(range(len(pts)-n,len(pts)))])
        cols.extend([color,color])
    return mesh(label,pts,faces,cols,bone,group,bevel,uv)

def octagon(cx,cy,z,w,d,c):
    a,b=w/2,d/2
    return [(cx+x,cy+y,z) for x,y in
            ((-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),(a-c,b),(-a+c,b),(-a,b-c),(-a,-b+c))]

def box(label,center,size,col,bone,group,bevel=.27,angle=(0,0,0),uv=None):
    from mathutils import Euler
    a,b,c=(x/2 for x in size)
    rot=Euler(tuple(radians(q) for q in angle)).to_matrix()
    pts=[tuple(Vector(center)+rot@Vector(p)) for p in
         ((-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c))]
    faces=((0,1,2,3),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7))
    return mesh(label,pts,faces,[col]*6,bone,group,bevel,uv)

def panel(label,outline,depth,col,bone,group,bevel=.22,uv=None):
    n=len(outline)
    pts=outline+[(x+depth[0],y+depth[1],z+depth[2]) for x,y,z in outline]
    faces=[tuple(range(n)),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(label,pts,faces,[col]*len(faces),bone,group,bevel,uv)

def segment(label,a,b,width,depth,col,bone,group,bevel=.25):
    a,b=Vector(a),Vector(b)
    v=(b-a).normalized()
    u=Vector((0,1,0)).cross(v).normalized()
    n=v.cross(u).normalized()
    coords=[]
    for end in (a,b):
        coords.append([tuple(end+u*w+n*d) for w,d in
                       ((-width/2,-depth/2),(width/2,-depth/2),(width/2,depth/2),(-width/2,depth/2))])
    return rings(label,coords,col,bone,group,bevel)

# The outer shell has a broad crown and a rear return. Its lip is a connected
# strip with a stepped interior boundary, dark lining, and a closed rear.
temp = [
    (0,183.8, 0,176.9),(8,183.8,8,176.9),(12,183.8,8,175.1),
    (18,183.8,15.2,175.1),(21,183.8,15.2,172.4),(23.7,182.1,19.1,172.4),
    (26.4,179,19.1,169.4),(27.8,176,21.5,169.4),(28.6,173,21.5,164.4),
    (29.3,169,23.8,164.4),(30.0,164,23.8,158.8),(30.7,160,26.0,158.8),
    (31.5,154.5,26.0,152.2),(32.5,149,27.5,152.2),(33.4,143.5,27.5,144.9),
    (27.5,136.2,23,140.5),(16,134,13,138.4),(0,133.8,0,138.1)]
orient=temp+[( -x,z,-xi,zi) for x,z,xi,zi in reversed(temp[1:-1])]
def yz_lip(z,x):
    return -32.4+.25*max(0,161-z)+.14*max(0,z-176)+.08*max(0,abs(x)-22)

front_rim=[(x,yz_lip(z,x),z) for x,z,u,v in orient]
inner_rim=[(u,yz_lip(v,u)-.4,v) for x,z,u,v in orient]
front_seam=[(x*1.024,-21.5+.15*max(0,151-z),z+1.4) for x,z,u,v in orient]
upper_side=[(x*.99,1.7+.13*max(0,152-z),z+2.1) for x,z,u,v in orient]
rear_turn=[(x*.94,17.2+.1*(173-z),z-.4 if z>155 else z+3) for x,z,u,v in orient]
crown_back=[(x*.75,22.7+.05*(171-z),157+(z-157)*.765+1.6) for x,z,u,v in orient]
lining=[(x*.93,-19,z+(159-z)*.095) for x,y,z in inner_rim]
lining_end=[(x*.72,14.4,z+(159-z)*.28) for x,y,z in inner_rim]
# Both ends are capped. The outer cap and the lining cap enclose the hood wall.
binding_edge=[tuple(Vector(a).lerp(Vector(b),.39)) for a,b in zip(front_rim,inner_rim)]
profiles=[crown_back,rear_turn,upper_side,front_seam,front_rim,binding_edge,inner_rim,lining,lining_end]

def hood_band(j,i):
    if j==5:
        outer=(orient[i][1]+orient[(i+1)%len(orient)][1])/2
        return "gold" if outer>=144 else "lining"
    return "hood-olive" if j<5 else "lining"

def hood_uv(p,face,axis,col):
    x,y,z=p
    if axis==0:
        return ((y+35)/60,(z-132)/53)
    if axis==2:
        return ((x+35)/70,(y+35)/61)
    return ((x+33)/66,(z-134)/52)

hood=rings("Hood · shell, stepped binding and returned lining",
           profiles,"hood-olive","Head",head,.29,hood_uv,hood_band)

# Planar face under the hood. The narrow ears stay behind the hair.
def face_uv(p,face,axis,col):
    x,y,z=p
    if col=="face":
        return ((x+19.4)/38.8,(z-137)/38)
    return ((y+22)/45,(z-136)/41)
rings("Head · face and temples",[
    octagon(0,-2.3,137.2,40.8,43.0,2),
    octagon(0,-2.4,174.9,42.4,43.0,2),
    octagon(0,-2.0,177.8,40,41.5,2.8),
],"skin","Head",head,.19,face_uv,lambda j,i:"face" if i==0 and j==0 else "skin")
box("Neck · warm skin",(0,-1,132.9),(17,17,13),"skin","Neck",chest,.65)

forelocks=[
    ([(-22,173),(-14,175),(-15,159),(-21,157),(-24,163)],-27.1),
    ([(-18,176),(-4,176),(-5,169),(-9,168),(-9,164.5),(-16,164),(-18,166)],-27.9),
    ([(-6,177),(9,177),(7,170),(3,170),(3,163.3),(-4,164.6),(-7,165)],-27.8),
    ([(8,176),(19,176),(21,170),(21,163),(17,163),(17,166),(12,166),(12,169),(9,169)],-26.8),
    ([(17,171),(22,169),(25,162),(25,149),(20,148),(18,156)],-25.7),
]
for i,(outline,depth) in enumerate(forelocks,1):
    panel(f"Fringe · {i}",[(x,depth+.095*x+.22*max(0,z-170),z) for x,z in outline],
          (0,6.9,0),"hair","Head",head,.38)
panel("Temple · tucked at braid root",[(-23,-25,166),(-17,-29,164),(-15,-27,151),(-16,-23,142),(-23,-23,144),(-26,-24,151)],
      (0,12,0),"hair","Head",head,.5)

# The dark lip of the scarf is narrow enough to leave the mouth visible.
def collar(z,w,d,shift,drop):
    return [(x,y,z+drop*(x/(w/2))*(.25+.75*max(0,-y/(d/2))))
            for x,y,z in octagon(0,shift,z,w,d,8)]
rings("Scarf · olive inner wrap",[
    collar(135.3,54,40,-4,-1.3),collar(137.0,55,45,-5.5,-.8),
    collar(140.9,54.5,45.1,-6.9,-1.1),collar(141.9,51,40,-7.1,-1.3)
],"lining","Head",chest,.45)
rings("Scarf · terracotta collar",[
    collar(126.3,51.5,42,-1.0,-1.1),
    collar(128.5,58.8,50,-2.8,-1.9),
    collar(134.3,57.5,50,-2.1,-.5),
    collar(136.9,52.5,43,-1.9,-1.5)
],"rust","Neck",chest,.5)
panel("Scarf · diagonal front fold",[
    (-26,-20.8,134.6),(-16,-29.4,134.9),(0,-31.5,132.5),
    (24,-25.6,127.7),(27,-22.8,126.9),(19,-24.9,123.2),
    (0,-30.7,126.5),(-15,-28.1,129),(-25,-21.4,130)
],(0,4,0),"rust","Neck",chest,.39)
panel("Scarf · fold under knot",[
    (17,-20.2,127),(24,-23.6,128),(31,-22,121.5),(33,-18.2,116.8),
    (29,-16.1,117.7),(26,-19.3,119),(23,-23.4,119.3)
],(0,4.7,0),"rust","Neck",chest,.42)

# Segments braid over and under one another. Their lower location is a rest
# fit on the chest. The root pieces follow the head, the plait follows Chest.
braid=[
    ((-22,-22,151),(-24,-28.3,140),13.5,11.8),
    ((-26,-28,143),(-20.3,-31.1,134),11,10),
    ((-25,-28.8,136),(-19.0,-30.5,127),11.9,9.8),
    ((-22,-32.0,130),(-16.0,-32.5,121),11.6,9.1),
    ((-19.3,-30.6,124),(-15.8,-28.6,116),10.4,8.2),
    ((-16.4,-31.3,119.2),(-14.3,-30.1,111.9),8.6,7.5),
    ((-15.7,-29.3,113),(-16.2,-26.3,107.7),6.4,5.7),
]
def plait_lobe(label,a,b,width,depth,bone):
    a,b=Vector(a),Vector(b)
    direction=(b-a).normalized()
    transverse=Vector((0,1,0)).cross(direction).normalized()
    thickness=direction.cross(transverse).normalized()
    profile=((-1,-.56),(-.57,-1),(.57,-1),(1,-.56),
             (1,.49),(.59,1),(-.59,1),(-1,.49))
    sections=[]
    for t,w,d,lean in ((0,.72,.82,-.2),(.23,1,1,.4),(.78,.89,.90,.1),(1,.65,.71,-.35)):
        mid=a.lerp(b,t)+transverse*lean
        sections.append([tuple(mid+transverse*(u*width*w/2)+thickness*(v*depth*d/2))
                         for u,v in profile])
    return rings(label,sections,"hair",bone,head,.17)

for i,(a,b,w,d) in enumerate(braid):
    plait_lobe(f"Braid · lobe {i+1}",a,b,w*.97,d*.95,"Head" if i<2 else "Chest")
segment("Braid · canvas tie",(-18.3,-30,121.7),(-16.2,-30,118.1),10.5,9.6,"linen","Chest",head,.32)

# Point crosses are sewn garment marks. Their pixels sit on actual seams
# at the side of the hood and over the right shoulder.
def projected_mark(label, support, origin, u, v, heading, pitch, col, bone, group):
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
               (0,.5,.86),(1,0,0),3.05,"thread","Head",head)

# Torso foundation and layered panels. Shoulder profile feeds into the
# drape of the cape instead of stopping at a flat shoulder cube.
rings("Shirt · woven body",[
    octagon(0,0,77,39,28,3.8),octagon(0,0,91,40,28,3.8),
    octagon(0,0,120,47,32,4.5),octagon(0,1,132,46.2,31,4.6),
    octagon(0,1,137,29,26,4.5)
],"linen","Chest",chest,.35)
for sign,side in ((-1,"R"),(1,"L")):
    def sash(x,y,z):
        return (sign*x,y,z)
    panel(f"Waistcoat · {side} brown front",
          [sash(*p) for p in ((20,-11.7,133),(13,-16.4,132.6),(5,-17.7,124),(8,-18.6,114),
            (5.8,-17.75,91),(7,-17,78),(16,-16,77),(20,-13.8,80),(23,-11.8,94),(24,-11,118))],
          (0,4,0),"saddle","Chest",chest,.54)
    panel(f"Waistcoat · {side} fold under arm",
          [sash(*p) for p in ((22,-12,129),(25,-5.0,129),(24,12.2,124),
            (20,15.1,79),(15,12,78),(19,-13,79),(21,-13,91))],
          (-sign*4,0,0),"darkleather","Chest",chest,.27)
    panel(f"Waistcoat · {side} lapel",
          [sash(*p) for p in ((10.7,-17.3,133),(3.7,-18.1,127.4),(7,-19.4,122.7),
            (5.3,-19,119.7),(12.7,-19,118),(17,-17.7,129))],
          (0,3.6,0),"saddle","Chest",chest,.42)
    segment(f"Waistcoat · {side} placket welt",sash(6.2,-18.7,91),sash(7.8,-19,113.5),
            2.4,1.6,"darkleather","Chest",chest)
    for k,(x,z) in enumerate(((13,111),(13.3,102.2),(12.9,93.7))):
        box(f"Waistcoat · {side} fastening {k}",sash(x,-18.9,z),(2.65,1.65,2.65),
            "darkleather","Chest",chest,.36)

segment("Diagonal harness · leather backing",(-20,-20.9,84),(23,-19.4,133),
        7.65,3.8,"darkleather","Chest",chest,.40)
segment("Diagonal harness · brown face",(-20,-22.8,84),(23,-21.6,133),
        6.2,2.0,"saddle","Chest",chest,.31)
for i in range(7):
    p=Vector((-20,-24.22,84)).lerp(Vector((23,-23.0,133)),.12+i*.121)
    box(f"Diagonal harness · edge stitch {i}",tuple(p+Vector((-1.85,0,1.65))),
        (1.55,.58,.60),"thread","Chest",chest,.05,angle=(0,-50,0))
a=Vector((-20,-22.8,84))
b=Vector((23,-21.6,133))
center=a.lerp(b,.57)+Vector((0,-2.4,0))
diag=Vector((b.x-a.x,0,b.z-a.z)).normalized()
across=Vector((diag.z,0,-diag.x))
corners=[tuple(center+9.0/2*(i*diag+j*across)) for i,j in ((-1,-1),(1,-1),(1,1),(-1,1))]
for i in range(4):
    segment(f"Diagonal harness · buckle side {i+1}",corners[i],corners[(i+1)%4],
            1.65,1.65,"metal","Chest",chest,.22)
segment("Diagonal harness · buckle pin",center-diag*2.8,center+diag*2.9,1.1,1.0,"metal","Chest",chest,.12)

# The waist is finished so the cropped render has a clean endpoint.
rings("Waist · under seam",[
    octagon(0,0,79.8,43.7,35,3.0),octagon(0,0,89.8,45.5,35.9,3.6),
],"darkleather","Chest",chest,.44)
box("Waist · buckle seat",(0,-19.3,85.6),(13.0,4.0,10.3),"saddle","Chest",chest,.53)
for i,(x,z,w,h) in enumerate(((0,90.0,12.4,2.1),(0,81.5,12.4,2.1),
                              (-5.3,85.8,2.15,7.8),(5.3,85.8,2.15,7.8))):
    box(f"Waist · square buckle {i}",(x,-22, z),(w,2.2,h),"metal","Chest",chest,.23)
box("Waist · buckle latch",(0,-22.65,85.6),(5.8,1.2,1.6),"metal","Chest",chest,.13)

# Cut the cape from a small set of broad drape planes, with a stepped hem.
def cape_outline(sign,side,drape):
    p=[(4,14,135),(14,15,135),(24,12,131),(32,7,126),(40,9,109),
       (37,16,89),(34,21,89),(34,23,86),(29,25,86),(29,29,81),(24,30,81),
       (24,32,84),(18,33,84),(18,34,88),(10,31,88),(4,29,91)]
    return [(sign*x,y+drape,z) for x,y,z in p]

for sign,side in ((-1,"R"),(1,"L")):
    panel(f"Cape · {side} hanging cloth",cape_outline(sign,side,0),
          (0,-3.1,0),"olive","Chest",shoulder,.32)
    panel(f"Cape · {side} return fold",
          [(sign*x,y,z) for x,y,z in ((13,18,133),(23,17,129),(28.8,28,101),(27,30,91),
            (22.5,33.4,91),(22.5,34.4,85),(19.5,34.4,85),(19.5,34,92),(17.8,31.4,98))],
          (0,-2.5,0),"lining","Chest",shoulder,.25)
rings("Cape · connecting back drape",[
    [(-14,17,133),(-6,19,134),(7,19,134),(14,17.5,133),
     (12,13.7,133),(6,14.2,133),(-6,14.2,133),(-12,13.7,133)],
    [(-15,20,111),(-6,22.7,111.5),(7,22.3,111.1),(14,20.8,111),
     (13,17.7,111),(6,19.4,111),(-6,19.6,111),(-14,17.5,111)],
    [(-14,30.3,86),(-6,33,84),(7,33.5,84),(14,31.5,87),
     (13,28.5,87),(6,30.9,84),(-6,30.4,84),(-13,28.1,86)]
],"olive","Chest",shoulder,.31)

# Two separate shoulder cloth pieces, draped around cuboid sleeves.
for sign,side in ((-1,"R"),(1,"L")):
    arm="UpperArm."+side
    fore="ForeArm."+side
    x=sign*33.7
    rings(f"{side} · sleeve",
          [octagon(x,0,z,w,d,bevel) for z,w,d,bevel in ((107,18.6,21.9,1.6),(119,19.4,22.1,2),(126.8,16.2,19.7,2.1),(129.5,13.6,17.8,2.4))],"linen",arm,shoulder,.35)
    rings(f"{side} · arm base",[
        octagon(x,0,101.3,17.6,19.7,.75),octagon(x,0,110,17.6,19.7,.9),
    ],"skin",arm,shoulder,.22)
    rings(f"{side} · arm base under wrap",[
        octagon(x,0,78.2,17.6,19.7,.75),octagon(x,0,101.7,17.6,19.7,.9)
    ],"skin",fore,shoulder,.22)
    for k,(z,bone,w) in enumerate(((104.9,arm,19.5),(101.7,fore,19.9),(98.0,fore,20.0),
                                   (94.5,fore,19.4),(91.1,fore,19.25))):
        rings(f"{side} · linen wrap {k+1}",[
            octagon(x,0,z-2.05,w,22,1.4),octagon(x,-.15,z+1.98,w+.2,22.5,1.7),
        ],"linen",bone,shoulder,.21)
    rings(f"{side} · glove edge",[
        octagon(x,0,78.8,19.8,21.7,1.35),octagon(x,0,89.8,20.2,22.1,1.6),
    ],"darkleather",fore,shoulder,.33)
    rings(f"{side} · wrist seam",[
        octagon(x,-.2,87.8,20.0,22.55,1.4),octagon(x,-.2,91.0,20.75,23.1,1.6),
    ],"darkleather",fore,shoulder,.24)

    # Cut a short cloak sleeve from the neckline to the upper arm. The
    # olive and rust share topology, so the square hem has no overlay gaps.
    def mantle_ring(z,w,d,offset=0,steps=False):
        regular=octagon(sign*32.2,0,z,w,d,min(5.4,w*.21))
        points=[]
        lower=(0,-1.8,-3.7,-5.1,-5.1,-3.4,-2.0,-.6)
        if sign>0:
            lower=tuple(reversed(lower))
        for i,a in enumerate(regular):
            b=regular[(i+1)%len(regular)]
            for t,delta in ((.03,0),(.49,0),(.52,2.65 if steps and i in (0,1,4,5) else 0),
                            (.98,2.65 if steps and i in (0,1,4,5) else 0)):
                x,y,_=Vector(a).lerp(Vector(b),t)
                fall=max(0,(abs(x)-25))*.23
                height=z-fall+offset+(lower[i]+delta-max(0,abs(x)-33)*.20 if steps else 0)
                points.append((x,y,height))
        return points
    lift=1.9 if side=="L" else 0
    sewn=[mantle_ring(134,18.6,27,lift),
          mantle_ring(131.4,21.8,29.8,lift),
          mantle_ring(127.5,25.8,33.8,lift),
          mantle_ring(116.5,27.1,34.0,lift,True),
          mantle_ring(112.0,28.6,34.8,lift,True),
          mantle_ring(110.5,25.4,31.8,lift,True)]
    cloth=rings(f"{side} · tailored shoulder cloak",sewn,"olive",arm,shoulder,.21,
                band=lambda j,i:("rust" if j==0 else "gold" if j==3 else "lining" if j==4 else "olive"))
    if side=="R":
        projected_mark("Right shoulder · visible mending",cloth,(-34.7,-48,118.9),
                       (.98,0,-.10),(.1,0,.98),(0,1,0),2.65,"thread",arm,shoulder)

for sign,side in ((-1,"R"),(1,"L")):
    j=rig.pose.bones["UpperArm."+side]
    j.rotation_mode="QUATERNION"
    local=j.bone.matrix_local.to_3x3().inverted() @ Vector((0,1,0))
    j.rotation_quaternion=Quaternion(local,radians(-sign*10))

# Readable studio lighting with a warm overhead key, a close face bounce and
# a wide grazing rim. The background is composited separately for review.
world=bpy.data.worlds.new("Studio · Aubergine ambient")
world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.21,.17,.19,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.31
scene.world=world
def lamp(label,at,aim,power,colour,size):
    ld=bpy.data.lights.new(label,"AREA")
    ld.energy=power
    ld.color=colour
    ld.size=size
    o=bpy.data.objects.new(label,ld)
    studio.objects.link(o)
    o.location=at
    o.rotation_euler=(Vector(aim)-o.location).to_track_quat("-Z","Y").to_euler()

lamp("Key · warm softbox",(-2.35,-2.7,3.77),(0,-.03,1.40),222,(1,.835,.696),1.78)
lamp("Eye bounce",(.42,-2.4,1.78),(0,-.13,1.49),63,(1,.89,.81),1.92)
lamp("Edge · high amber",(-1.15,1.8,3.42),(0,.02,1.47),268,(1,.77,.54),1.21)
lamp("Cool side fill",(2.24,.24,2.23),(0,0,1.34),74,(.79,.83,1),2.0)

def camera(name,yaw,pitch,scale):
    a,b=radians(yaw),radians(pitch)
    direction=Vector((sin(a)*cos(b),-cos(a)*cos(b),sin(b)))
    target=Vector((0,-.01,1.348))
    cd=bpy.data.cameras.new(name)
    cd.type="ORTHO"
    cd.ortho_scale=scale
    ob=bpy.data.objects.new(name,cd)
    studio.objects.link(ob)
    ob.location=target+direction*4.9
    ob.rotation_euler=(target-ob.location).to_track_quat("-Z","Y").to_euler()
    return ob

cameras={
    "Front":camera("Front",0,2.4,1.175),
    "Hero":camera("Hero", -32, 7.2,1.175),
    "Profile":camera("Profile", -81, 4,1.175),
    "Back":camera("Back",176,4,1.175),
}
scene.render.engine="CYCLES"
scene.cycles.samples=48 if FINAL else 20
scene.cycles.use_denoising=True
scene.render.resolution_x=950 if FINAL else 536
scene.render.resolution_y=1120 if FINAL else 632
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="AgX"
scene.view_settings.look="AgX - Medium High Contrast"
scene.view_settings.exposure=.08
scene.render.threads_mode="FIXED"
scene.render.threads=12
OUT.mkdir(parents=True,exist_ok=True)
for i,(name,cam) in enumerate(cameras.items(),1):
    marker=scene.timeline_markers.new(name,frame=i)
    marker.camera=cam
    if name=="Back" and not FINAL:
        continue
    scene.frame_set(i)
    scene.camera=cam
    scene.render.filepath=str(OUT/(name.lower()+".png"))
    bpy.ops.render.render(write_still=True)

scene.camera=cameras["Hero"]
scene.frame_set(2)
scene.render.filepath="//Forager portrait.png"
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.color_type="MATERIAL"
bpy.data.orphans_purge(do_recursive=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"The Forager.blend"),compress=True,relative_remap=False)



