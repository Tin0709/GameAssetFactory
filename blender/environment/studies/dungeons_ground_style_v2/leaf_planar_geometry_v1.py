"""Reusable planar-corner clipping for current leaf slabs and assembly contacts."""
import bpy
from mathutils import Vector
UV_NAME='UV_UserLeafTile_1RepeatPerMetre'
def records(mesh):
    result=[];color=mesh.color_attributes.get('Color')
    for p in mesh.polygons:
        corners=[{'p':mesh.vertices[mesh.loops[li].vertex_index].co.copy(),'u':mesh.uv_layers[0].data[li].uv.copy(),'c':list(color.data[li].color)if color else None}for li in p.loop_indices]
        result.append({'corners':corners,'part':mesh.attributes['leaf_part'].data[p.index].value if mesh.attributes.get('leaf_part')else-1,'side':mesh.attributes['core_face'].data[p.index].value if mesh.attributes.get('core_face')else mesh.attributes['bushy_side'].data[p.index].value if mesh.attributes.get('bushy_side')else-1})
    return result

def interpolate(a,b,t):return {'p':a['p'].lerp(b['p'],t),'u':a['u'].lerp(b['u'],t),'c':[x+(y-x)*t for x,y in zip(a['c'],b['c'])]if a['c']is not None else None}
def clip(record,z,above):
    points=record['corners'];out=[]
    for a,b in zip(points,points[1:]+points[:1]):
        ia=a['p'].z>=z-1e-8 if above else a['p'].z<=z+1e-8;ib=b['p'].z>=z-1e-8 if above else b['p'].z<=z+1e-8
        if ia:out.append(a)
        if ia!=ib:out.append(interpolate(a,b,(z-a['p'].z)/(b['p'].z-a['p'].z)))
    clean=[]
    for p in out:
        if not clean or(p['p']-clean[-1]['p']).length>1e-7:clean.append(p)
    if len(clean)>1 and(clean[0]['p']-clean[-1]['p']).length<1e-7:clean.pop()
    if len(clean)<3:return None
    return dict(record,corners=clean)
def subtract_interval(record,lo,hi):
    zlo=min(c['p'].z for c in record['corners']);zhi=max(c['p'].z for c in record['corners'])
    if zhi<=lo+1e-7 or zlo>=hi-1e-7:return [record]
    return [r for r in(clip(record,lo,False),clip(record,hi,True))if r]
def make_mesh(name,items,material):
    verts=[];faces=[];uvs=[];colors=[];parts=[];sides=[]
    for record in items:
        start=len(verts);verts.extend(tuple(c['p'])for c in record['corners']);faces.append(tuple(range(start,len(verts))));uvs.append([c['u']for c in record['corners']]);colors.append([c['c']for c in record['corners']]);parts.append(record['part']);sides.append(record['side'])
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.materials.append(material);m.update();uv=m.uv_layers.new(name=UV_NAME);part=m.attributes.new(name='leaf_part',type='INT',domain='FACE');side=m.attributes.new(name='core_face',type='INT',domain='FACE');color=m.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')if any(v is not None for row in colors for v in row)else None
    for p,coords,rgba,kind,direction in zip(m.polygons,uvs,colors,parts,sides):
        part.data[p.index].value=kind;side.data[p.index].value=direction
        for li,coord,c in zip(p.loop_indices,coords,rgba):
            uv.data[li].uv=coord
            if color:color.data[li].color=c or(1,1,1,1)
    return m

def contacts(cells,index):
    a=cells[index];ap=Vector(a['blender_bottom_center']);height=a['height_m'];found={}
    for j,b in enumerate(cells):
        if j==index:continue
        bp=Vector(b['blender_bottom_center']);d=bp-ap;lo=max(ap.z,bp.z);hi=min(ap.z+height,bp.z+b['height_m'])
        if hi-lo>1e-7:
            for side,axis,sign in((0,0,1),(1,0,-1),(2,1,1),(3,1,-1)):
                other=1-axis
                if abs(d[axis]-sign)<1e-7 and abs(d[other])<1e-7:found.setdefault(side,[]).append([lo-ap.z,hi-ap.z])
        if abs(d.x)<1e-7 and abs(d.y)<1e-7:
            if abs(ap.z+height-bp.z)<1e-7:found[4]=[[0,height]]
            if abs(bp.z+b['height_m']-ap.z)<1e-7:found[5]=[[0,height]]
    return found

def trimmed(items,contact,kind):
    result=[]
    for record in items:
        side=record['side'];pending=[record]
        if kind=='core'and record['part']!=0:result.extend(pending);continue
        if side in contact:
            if side in(4,5):continue
            for lo,hi in contact[side]:pending=[piece for r in pending for piece in subtract_interval(r,lo,hi)]
        result.extend(pending)
    return result
