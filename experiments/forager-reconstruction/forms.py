"""World-space measurements, closed fabric panels, and cuboid character tooling."""
from pathlib import Path
from math import radians
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

U=1.8/350
ROOT=Path(__file__).resolve().parent
MATERIALS={}
RIG=None

def collection(name,parent):
    c=bpy.data.collections.new(name)
    parent.children.link(c)
    return c

def material(name,rough=.86,metal=0,solid=None,emission=0):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    shader=m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value=rough
    shader.inputs["Metallic"].default_value=metal
    shader.inputs["Specular IOR Level"].default_value=.25
    if solid is None:
        tex=m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image=bpy.data.images.load(str(ROOT/"private/paint"/f"{name}.png"))
        tex.image.pack()
        tex.interpolation="Closest"
        m.node_tree.links.new(tex.outputs["Color"],shader.inputs["Base Color"])
    else:
        shader.inputs["Base Color"].default_value=(*solid,1)
    if emission:
        shader.inputs["Emission Color"].default_value=(*solid,1)
        shader.inputs["Emission Strength"].default_value=emission
    MATERIALS[name]=m

def mesh(name,pts,faces,colors,col,bone=None,bevel=0,uv=None,normal_tip=None):
    data=bpy.data.meshes.new(name)
    data.from_pydata([Vector(p)*U for p in pts],[],faces)
    bm=bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    if normal_tip is not None:
        bm.faces.ensure_lookup_table()
        i,axis,sign=normal_tip
        if bm.faces[i].normal[axis]*sign<0:
            bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    data.update()

    names=list(dict.fromkeys(colors))
    for c in names:
        data.materials.append(MATERIALS[c])
    layer=data.uv_layers.new(name="Pixel UV")
    for face in data.polygons:
        color=colors[face.index]
        face.material_index=names.index(color)
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        a,b=((1,2),(0,2),(0,1))[axis]
        for loop in face.loop_indices:
            p=pts[data.loops[loop].vertex_index]
            layer.data[loop].uv=uv(p,axis,face.normal,color) if uv else (
                p[a]/63+.173*axis,p[b]/67+.137*axis)
    obj=bpy.data.objects.new(name,data)
    col.objects.link(obj)
    if bone:
        joint=RIG.data.bones[bone]
        obj.parent=RIG
        obj.parent_type="BONE"
        obj.parent_bone=bone
        obj.matrix_parent_inverse=(joint.matrix_local@Matrix.Translation((0,joint.length,0))).inverted()
    if bevel:
        edge=obj.modifiers.new("Tiny facet at exposed edges","BEVEL")
        edge.width=bevel*U
        edge.segments=1
        edge.limit_method="ANGLE"
        edge.angle_limit=radians(26)
    return obj

def octagon(center,w,d,corner):
    x,y,z=center
    a,b=w/2,d/2
    c=min(corner,a*.75,b*.75)
    return [(x+u,y+v,z) for u,v in ((-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),
                                    (a-c,b),(-a+c,b),(-a,b-c),(-a,-b+c))]

def loft(name,rings,c,col,bone=None,bevel=0,shade=None,uv=None,caps=True):
    n=len(rings[0])
    pts=[tuple(p) for ring in rings for p in ring]
    faces,colors=[],[]
    for row in range(len(rings)-1):
        for i in range(n):
            a=row*n+i
            b=row*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
            colors.append(shade(row,i) if shade else c)
    if caps:
        faces.extend((tuple(range(n)),tuple(range(len(pts)-n,len(pts)))))
        colors.extend((c,c))
    return mesh(name,pts,faces,colors,col,bone,bevel,uv)

def block(name,center,size,c,col,bone=None,bev=.4,angles=(0,0,0)):
    axis=Euler(tuple(radians(r) for r in angles)).to_matrix()
    a,b,h=(v/2 for v in size)
    pts=[tuple(Vector(center)+axis@Vector(q)) for q in
         ((-a,-b,-h),(a,-b,-h),(a,b,-h),(-a,b,-h),(-a,-b,h),(a,-b,h),(a,b,h),(-a,b,h))]
    faces=[(0,1,2,3),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return mesh(name,pts,faces,[c]*6,col,bone,bev)

def panel(name,outline,offset,c,col,bone=None,bev=.3,uv=None):
    n=len(outline)
    pts=list(outline)+[tuple(Vector(p)+Vector(offset)) for p in outline]
    faces=[tuple(range(n)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,pts,faces,[c]*len(faces),col,bone,bev,uv)

def band(name,a,b,w,d,c,col,bone=None,bev=.38,taper=(1,1),side_axis=(0,1,0)):
    a,b=Vector(a),Vector(b)
    long=(b-a).normalized()
    side=Vector(side_axis).cross(long).normalized()
    cross=long.cross(side).normalized()
    levels=[]
    shape=((-1,-1),(1,-1),(1,1),(-1,1)) if bev==0 else (
        (-1,-.69),(-.69,-1),(.69,-1),(1,-.69),(1,.69),(.69,1),(-.69,1),(-1,.69))
    for center,factor in zip((a,b),taper):
        levels.append([center+side*(x*w/2*factor)+cross*(y*d/2*factor) for x,y in shape])
    return loft(name,levels,c,col,bone,bev)

def belt_frame(name,center,side,up,w,h,thick,c,col,bone=None):
    mid=Vector(center)
    u,v=Vector(side).normalized(),Vector(up).normalized()
    corners=[mid+u*x*w/2+v*y*h/2 for x,y in ((-1,-1),(1,-1),(1,1),(-1,1))]
    a=(u.cross(v)).normalized()
    for i,q in enumerate(corners):
        band(name+" "+str(i+1),q,corners[(i+1)%4],thick,thick*1.18,c,col,bone,
             bev=.21,side_axis=a)
    bar=mid+a*1.15
    band(name+" latch",bar-u*w*.21,bar+u*w*.22,thick*.62,thick*.72,c,col,bone,
         bev=.11,side_axis=a)

