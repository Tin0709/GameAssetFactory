"""Forest Canopy V3: original cuboid leaf masses, never spherical terraces.

Blender 5.2 --background --factory-startup --python <this file>
Writes only the two forest_canopy_v3 folders. V2 remains untouched.
"""
import bpy
import bmesh
import hashlib
import json
import math
import random
import struct
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
OUT=ROOT/'game_mobile_3d/assets/environment/forest_canopy_v3'
OUT.mkdir(parents=True,exist_ok=True)
LEAVES=['#426831','#507637','#648440','#759249','#385c30','#547241','#839b51']
BARK=['#71583b','#846643','#96794f','#614b34','#a18456']
FERN=['#5b7f3e','#73914c','#859f55','#466936','#628644','#8aa25d']


def rgba(h):
    return tuple(int(h[n:n+2],16)/255 for n in (1,3,5))+(1.0,)


def linear(v):
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4


def hashed(i,j,k,s):
    return ((i*73856093)^(j*19349663)^(k*83492791)^(s*2654435761))&0xffffffff


def colored_material(name):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.use_backface_culling=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.95
    bsdf.inputs['Metallic'].default_value=0
    bsdf.inputs['Specular IOR Level'].default_value=.12
    color=mat.node_tree.nodes.new('ShaderNodeVertexColor')
    color.layer_name='Color'
    mat.node_tree.links.new(color.outputs['Color'],bsdf.inputs['Base Color'])
    return mat


class Geometry:
    def __init__(self):
        self.points=[]
        self.faces=[]
        self.colors=[]

    def face(self,points,color):
        start=len(self.points)
        self.points.extend(tuple(p) for p in points)
        self.faces.append(tuple(range(start,start+len(points))))
        self.colors.append(color)

    def mesh(self,name,collection,material,palette):
        # Weld matching points. Per-corner colors and flat normals stay intact.
        unique={}
        positions=[]
        mapping=[]
        for p in self.points:
            key=tuple(round(x,7) for x in p)
            if key not in unique:
                unique[key]=len(positions)
                positions.append(p)
            mapping.append(unique[key])
        faces=[tuple(mapping[i] for i in f) for f in self.faces]
        mesh=bpy.data.meshes.new(name+'_AuthoredGeometry')
        mesh.from_pydata(positions,[],faces)
        mesh.update()
        attribute=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for polygon,color in zip(mesh.polygons,self.colors):
            for loop in polygon.loop_indices:attribute.data[loop].color_srgb=rgba(palette[color%len(palette)])
            polygon.use_smooth=False
        obj=bpy.data.objects.new(name,mesh)
        collection.objects.link(obj)
        mesh.materials.append(material)
        obj['authoring_status']='Original V3 study - awaiting user art review'
        obj['units']='metres, local bottom-centre origin, Blender Z-up'
        return obj


def add_box(cells,low,high):
    for i in range(low[0],high[0]):
        for j in range(low[1],high[1]):
            for k in range(low[2],high[2]):cells.add((i,j,k))


def repair_voxel_edges(cells):
    """Fill diagonal-only edge contacts so the leaf boundary is manifold."""
    fills=0
    for _ in range(6):
        add=set()
        for c in list(cells):
            for fixed in range(3):
                a,b=(fixed+1)%3,(fixed+2)%3
                for da in (-1,1):
                    for db in (-1,1):
                        qa=list(c);qa[a]+=da
                        qb=list(c);qb[b]+=db
                        qab=list(qa);qab[b]+=db
                        if tuple(qab) in cells and tuple(qa) not in cells and tuple(qb) not in cells:
                            add.add(min(tuple(qa),tuple(qb)))
        if not add:break
        cells.update(add);fills+=len(add)
    return fills


def box_crown(boxes,seed,detail=1.0):
    """Five authored bulk boxes; sparse attached leaf tufts on their exposed faces.

    Secondary patches are 2-3 cells wide and 1-2 cells proud, with no continuous
    height-ring construction. The seeded choices only decorate the authored bulk.
    """
    cells=set()
    for low,high in boxes:add_box(cells,low,high)
    rng=random.Random(seed)
    original=set(cells)
    edges=[]
    for c in sorted(original):
        count=0
        for axis in range(3):
            for sign in (-1,1):
                n=list(c);n[axis]+=sign
                count+=tuple(n) not in original
        if count>=2:edges.append(c)
    # Break hard bulk corners in small rectangular bites, not repeated bevel rings.
    for c in edges:
        if hashed(*c,seed)%13==0:
            cells.discard(c)
    exposed=[]
    for c in sorted(original):
        for axis in range(3):
            for sign in (-1,1):
                n=list(c);n[axis]+=sign
                if tuple(n) not in original:exposed.append((c,axis,sign))
    rng.shuffle(exposed)
    occupied_patches=[]
    for c,axis,sign in exposed:
        if axis==2 and sign<0 and rng.random()<.65:continue
        if any(sum(abs(c[q]-p[q]) for q in range(3))<4 for p in occupied_patches):continue
        if rng.random()>.18*detail:continue
        occupied_patches.append(c)
        u,v=(axis+1)%3,(axis+2)%3
        width=rng.choice([1,2,2,3])
        height=rng.choice([1,2,2,3])
        depth=rng.choice([1,1,1,2])
        # Every patch has a broad attachment to its bulk face.
        for du in range(width):
            for dv in range(height):
                support=list(c);support[u]+=du;support[v]+=dv
                if tuple(support) not in original:continue
                for outward in range(1,depth+1):
                    p=list(support);p[axis]+=sign*outward
                    cells.add(tuple(p))
    repair_count=repair_voxel_edges(cells)
    return cells,{'bulk_clumps':len(boxes),'surface_leaf_patches':len(occupied_patches),'manifold_edge_fills':repair_count}


def color_index(i,j,k,axis,sign,seed):
    # Surface pigmentation uses irregular multi-cell rectangles, independent of
    # horizontal height bands. Top/side/underside palettes are compact and related.
    if axis==0:u,v=j,k
    elif axis==1:u,v=i,k
    else:u,v=i,j
    patch=hashed((u+(v//3)%2)//2,(v+1)//3,(i+j+k)//7,seed)%17
    if axis==2 and sign<0:return 4 if patch<11 else 0
    if axis==2:
        return 2 if patch<5 else (3 if patch<11 else (1 if patch<14 else 6))
    return 0 if patch<5 else (1 if patch<10 else (2 if patch<13 else (5 if patch<16 else 3)))


def voxel_surface(cells,scale,seed):
    planes=defaultdict(dict)
    for c in sorted(cells):
        for axis in range(3):
            u,v=(axis+1)%3,(axis+2)%3
            for sign in (-1,1):
                n=list(c);n[axis]+=sign
                if tuple(n) in cells:continue
                plane=c[axis]+(1 if sign>0 else 0)
                planes[(axis,sign,plane)][(c[u],c[v])]=color_index(*c,axis,sign,seed)
    rectangles=[]
    raw=sum(len(p) for p in planes.values())
    for (axis,sign,plane),points in sorted(planes.items()):
        u,v=(axis+1)%3,(axis+2)%3
        while points:
            a,b=min(points);color=points[(a,b)]
            w=1
            while points.get((a+w,b),-1)==color:w+=1
            h=1
            while all(points.get((a+x,b+h),-1)==color for x in range(w)):h+=1
            corners=[]
            for cu,cv in [(a,b),(a+w,b),(a+w,b+h),(a,b+h)]:
                p=[0,0,0];p[axis]=plane;p[u]=cu;p[v]=cv;corners.append(tuple(p))
            if sign<0:corners.reverse()
            rectangles.append((corners,color))
            for x in range(w):
                for y in range(h):del points[(a+x,b+y)]
    # Split greedy-rectangle boundary edges wherever a neighbouring face ends.
    # This removes T-junctions and creates a genuinely closed welded source mesh.
    vertices={p for points,_ in rectangles for p in points}
    lines=defaultdict(set)
    for p in vertices:
        for axis in range(3):
            other=[q for q in range(3) if q!=axis]
            lines[(axis,p[other[0]],p[other[1]])].add(p[axis])
    geo=Geometry()
    for points,color in rectangles:
        boundary=[]
        for index,p in enumerate(points):
            q=points[(index+1)%4]
            axis=next(a for a in range(3) if p[a]!=q[a])
            other=[a for a in range(3) if a!=axis]
            values=sorted((v for v in lines[(axis,p[other[0]],p[other[1]])] if min(p[axis],q[axis])<=v<=max(p[axis],q[axis])),reverse=p[axis]>q[axis])
            for value in values[:-1]:
                point=list(p);point[axis]=value
                boundary.append(tuple(point[a]*scale[a] for a in range(3)))
        # Blender's tessellator accepts the collinear split edge points and keeps
        # the native polygon editable. Source checks also audit triangulated mesh.
        geo.face(boundary,color)
    return geo,{'exposed_voxel_faces':raw,'merged_surface_polygons':len(rectangles),'leaf_voxels':len(cells)}


def branch(geo,centers,widths,offset=0):
    """Continuous flat-normal trunk/branch, one closed volume without hidden caps."""
    ring=[]
    shape=[(-1,-.68),(-.68,-1),(.68,-1),(1,-.68),(1,.68),(.68,1),(-.68,1),(-1,.68)]
    for index,center in enumerate(centers):
        c=Vector(center)
        d=Vector(centers[min(index+1,len(centers)-1)])-Vector(centers[max(0,index-1)])
        d.normalize();u=d.cross(Vector((0,1,0))).normalized();v=d.cross(u).normalized()
        ring.append([tuple(c+(u*x+v*y)*widths[index]*.5) for x,y in shape])
    for n in range(len(ring)-1):
        for a in range(8):
            b=(a+1)%8
            color=[0,3,0,1,2,1,0,3][a]
            if (a+n+offset)%7==0:color=4
            geo.face([ring[n][a],ring[n][b],ring[n+1][b],ring[n+1][a]],color)
    geo.face(list(reversed(ring[0])),3);geo.face(ring[-1],1)


def bark(variant):
    g=Geometry()
    if variant=='a':
        branch(g,[(0,0,.0),(.02,.01,.55),(-.03,.035,1.30),(.08,.03,2.10),(.15,.04,2.9),(.22,.11,3.7)],[.59,.49,.43,.35,.25,.15])
        branch(g,[(.045,.02,1.65),(-.52,.08,2.29),(-1.01,.13,2.93)],[.28,.22,.13],2)
        branch(g,[(.08,.02,1.94),(.70,-.15,2.60),(1.33,-.23,3.24)],[.27,.21,.12],3)
        branch(g,[(.08,.06,2.03),(-.12,.61,2.52),(-.35,1.17,3.25)],[.24,.18,.12],1)
    else:
        branch(g,[(0,0,0),(-.03,.01,.48),(.04,.03,1.14),(.14,.06,1.82),(.24,.14,2.45),(.32,.24,3.32)],[.55,.46,.40,.32,.23,.13])
        branch(g,[(.06,.03,1.49),(-.43,.13,2.09),(-1.03,.24,2.73)],[.28,.23,.13],3)
        branch(g,[(.12,.04,1.76),(.62,-.30,2.26),(1.21,-.52,2.9)],[.27,.21,.12],2)
        branch(g,[(.08,.03,1.63),(-.08,.64,2.18),(.09,1.02,2.78)],[.22,.18,.10],1)
    # Bottom trunk is horizontal and exactly at grade; root wedges share its soil.
    g.points=[(x,y,max(0,z)) for x,y,z in g.points]
    for n,(x,y) in enumerate([(.80,.1),(-.75,-.20),(.24,-.76),(-.15,.71)]):
        d=Vector((x,y,0)).normalized();s=Vector((-d.y,d.x,0))
        start=d*.06;end=Vector((x,y,0))
        points=[start-s*.17,start+s*.17,end+s*.055,end-s*.055]
        top=[p+Vector((0,0,.28 if i<2 else .055)) for i,p in enumerate(points)]
        points.reverse();top.reverse()
        g.face(list(reversed(points)),3);g.face(top,1+n%2)
        for a in range(4):
            b=(a+1)%4;g.face([points[a],points[b],top[b],top[a]],n%3)
    return g


def trees(collection,mats):
    # Cell coordinates: large clumps differ in width, depth, height and elevation.
    # No nested rings, ellipsoids, or repeated horizontal terrace construction.
    layouts={
      'tree_oak_a':[((-10,-5,16),(-1,5,26)),((-3,-6,20),(6,5,31)),((4,-4,18),(12,5,27)),((-5,3,18),(4,11,28)),((-6,-10,15),(3,-2,23))],
      'tree_oak_b':[((-11,-3,14),(-2,7,23)),((-5,-8,16),(4,1,25)),((1,-5,17),(10,4,26)),((-2,2,20),(6,10,28))],
    }
    result={}
    for name,boxes in layouts.items():
        c=bpy.data.collections.new(name);collection.children.link(c)
        seed=37 if name.endswith('a') else 81
        cells,notes=box_crown(boxes,seed)
        geo,stats=voxel_surface(cells,(.15,.15,.15),seed)
        trunk=bark(name[-1]).mesh('Bark',c,mats['bark'],BARK)
        leaves=geo.mesh('Leaves',c,mats['leaf'],LEAVES)
        for o in (trunk,leaves):o['asset_id']=name
        result[name]={'objects':[trunk,leaves],'leaf_cell_m':[.15,.15,.15],**notes,**stats}
    return result


def frond(geo,origin,angle,length,height,width,color):
    forward=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-math.sin(angle),math.cos(angle),0))
    # Broad, blunt leaf: discrete width changes keep squared silhouette tips.
    contour=[(0,-.5),(.25,-.5),(.25,-1),(.65,-1),(.65,-.74),(1,-.74),(1,.74),(.65,.74),(.65,1),(.25,1),(.25,.5),(0,.5)]
    top=[]
    for t,w in contour:
        p=Vector(origin)+forward*(t*length)+side*(w*width*.5)+Vector((0,0,.045+height*math.sin(t*math.pi*.65)))
        top.append(p)
    bottom=[p-Vector((0,0,.035)) for p in top]
    center=Vector(origin)+forward*length*.48+Vector((0,0,height*.91+.068))
    lower_center=center-Vector((0,0,.065))
    for i in range(len(top)):
        j=(i+1)%len(top)
        geo.face([center,top[i],top[j]],color if i%4 else min(color+1,2))
        geo.face([lower_center,bottom[j],bottom[i]],3)
        geo.face([top[i],bottom[i],bottom[j],top[j]],3 if i%3 else color)


def shrubs(collection,mats):
    result={}
    c=bpy.data.collections.new('shrub_leaf');collection.children.link(c)
    boxes=[((-4,-2,1),(0,3,5)),((-1,-4,2),(3,0,6)),((0,-1,3),(4,3,7)),((-2,2,1),(2,5,4))]
    cells,notes=box_crown(boxes,16,.55)
    cells.update({(0,0,0),(-1,0,0),(0,0,1),(-1,0,1)})
    repair_voxel_edges(cells)
    geo,stats=voxel_surface(cells,(.12,.12,.12),16)
    o=geo.mesh('Leaves',c,mats['leaf'],LEAVES)
    result['shrub_leaf']={'objects':[o],'leaf_cell_m':[.12,.12,.12],**notes,**stats}
    c=bpy.data.collections.new('shrub_fern');collection.children.link(c)
    geo=Geometry()
    for n in range(7):
        frond(geo,(.015*math.sin(n),.02*math.cos(n),.01),n*math.tau/7+.12,[.58,.65,.52,.61,.55,.62,.50][n],[.30,.36,.40,.31,.38,.29,.43][n],.38,n%3)
    for n in range(2):frond(geo,(.013-n*.04,-.009+n*.038,.10+n*.03),n*math.pi+.31,.32,.60,.29,1)
    # A small closed stem provides ground contact below the broad leaves.
    stem={(0,0,0),(0,0,1)}
    stem_geo,_=voxel_surface(stem,(.12,.12,.08),2)
    for f,color in zip(stem_geo.faces,stem_geo.colors):geo.face([(stem_geo.points[i][0]-.06,stem_geo.points[i][1]-.06,stem_geo.points[i][2]) for i in f],3)
    o=geo.mesh('Leaves',c,mats['fern'],FERN)
    result['shrub_fern']={'objects':[o],'broad_leaf_fronds':9,'smallest_tip_width_m':.29*.5}
    for name,data in result.items():
        for o in data['objects']:o['asset_id']=name
    return result


def mesh_audit(obj):
    bm=bmesh.new();bm.from_mesh(obj.data)
    boundary=sum(1 for e in bm.edges if e.is_boundary)
    nonmanifold=sum(1 for e in bm.edges if not e.is_manifold)
    assert all(e.is_contiguous for e in bm.edges),(obj.name,'inconsistent adjacent face winding')
    zero_faces=sum(1 for f in bm.faces if f.calc_area()<1e-10)
    volume=bm.calc_volume(signed=True)
    unvisited=set(bm.faces);component_volumes=[]
    while unvisited:
        stack=[unvisited.pop()];component=[]
        while stack:
            f=stack.pop();component.append(f)
            for edge in f.edges:
                for adjacent in edge.link_faces:
                    if adjacent in unvisited:unvisited.remove(adjacent);stack.append(adjacent)
        signed=0.0
        for f in component:
            coords=[v.co for v in f.verts]
            for index in range(1,len(coords)-1):signed+=coords[0].dot(coords[index].cross(coords[index+1]))/6
        component_volumes.append(signed)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    tri_zero=sum(1 for f in bm.faces if f.calc_area()<1e-10)
    tri_nonmanifold=sum(1 for e in bm.edges if not e.is_manifold)
    triangles=len(bm.faces)
    bm.free()
    result={'mesh':obj.name,'triangles':triangles,'boundary_edges':boundary,'nonmanifold_edges':nonmanifold,
            'zero_area_faces':zero_faces,'zero_area_triangles':tri_zero,'triangulated_nonmanifold_edges':tri_nonmanifold,
            'signed_volume_m3':volume,'closed_components':len(component_volumes),'component_volumes_m3':component_volumes,
            'all_flat_normals':all(not p.use_smooth for p in obj.data.polygons)}
    assert boundary==0 and nonmanifold==0 and zero_faces==0 and tri_zero==0 and tri_nonmanifold==0,(obj.name,result)
    assert volume>0,(obj.name,'inward normals',volume)
    assert all(v>0 for v in component_volumes),(obj.name,'inward component normals',component_volumes)
    return result


def write_import_contract():
    (OUT/'vertex_color_import.gd').write_text('''@tool
extends EditorScenePostImport
## GLB COLOR_0 contains linear albedo; these native materials work outside the study.
func _post_import(scene: Node) -> Object:
\tfor node in scene.find_children("*", "MeshInstance3D", true, false):
\t\tfor index in node.mesh.get_surface_count():
\t\t\tvar material = node.mesh.surface_get_material(index)
\t\t\tif material is BaseMaterial3D:
\t\t\t\tmaterial.vertex_color_use_as_albedo = true
\t\t\t\tmaterial.vertex_color_is_srgb = false
\t\t\t\tmaterial.roughness = 0.95
\t\t\t\tmaterial.metallic = 0.0
\treturn scene
''',encoding='utf-8')
    for name in ('tree_oak_a','tree_oak_b','shrub_leaf','shrub_fern'):
        path='res://assets/environment/forest_canopy_v3/'+name+'.glb'
        dest='res://.godot/imported/'+name+'.glb-'+hashlib.md5(path.encode()).hexdigest()+'.scn'
        config=OUT/(name+'.glb.import')
        if config.exists():continue # Preserve Godot-assigned UID and imported metadata.
        config.write_text(f'''[remap]
importer="scene"
importer_version=1
type="PackedScene"
path="{dest}"

[deps]
source_file="{path}"
dest_files=["{dest}"]

[params]
nodes/root_scale=1.0
nodes/apply_root_scale=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
animation/import=false
import_script/path="res://assets/environment/forest_canopy_v3/vertex_color_import.gd"
_subresources={{}}
gltf/naming_version=2
''',encoding='utf-8')


def read_glb(path):
    raw=path.read_bytes();magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw)
    count=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+count]);binary=20+count+8
    return raw,doc,binary


def accessor_values(raw,doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    code,size,divisor={5126:('f',4,1),5125:('I',4,1),5123:('H',2,65535 if a.get('normalized') else 1),5121:('B',1,255 if a.get('normalized') else 1)}[a['componentType']]
    stride=view.get('byteStride',count*size)
    start=binary+view.get('byteOffset',0)+a.get('byteOffset',0)
    return [tuple(v/divisor for v in struct.unpack_from('<'+code*count,raw,start+i*stride)) for i in range(a['count'])]


def glb_audit(path):
    raw,doc,binary=read_glb(path)
    prims=[p for m in doc['meshes'] for p in m['primitives']]
    names=[n.get('name','') for n in doc['nodes'] if 'mesh' in n]
    assert sorted(names)==(['Bark','Leaves'] if path.stem.startswith('tree') else ['Leaves'])
    assert len(prims)==len(names) and len(doc['materials'])==len(names)
    assert not doc.get('images') and not doc.get('animations') and not doc.get('skins')
    assert all(m.get('alphaMode','OPAQUE')=='OPAQUE' and not m.get('doubleSided',False) for m in doc['materials'])
    triangles=0;error=0;normal_error=0;all_positions=[]
    for p in prims:
        assert 'COLOR_0' in p['attributes'] and 'NORMAL' in p['attributes']
        triangles+=doc['accessors'][p['indices']]['count']//3
        matname=doc['materials'][p['material']]['name']
        palette=BARK if 'Bark' in matname else (FERN if 'Fern' in matname else LEAVES)
        allowed=[tuple(linear(x) for x in rgba(h)[:3]) for h in palette]
        for color in accessor_values(raw,doc,binary,p['attributes']['COLOR_0']):
            error=max(error,min(max(abs(color[q]-a[q]) for q in range(3)) for a in allowed))
            assert len(color)==3 or color[3]==1
        normals=accessor_values(raw,doc,binary,p['attributes']['NORMAL'])
        positions=accessor_values(raw,doc,binary,p['attributes']['POSITION'])
        indices=[int(v[0]) for v in accessor_values(raw,doc,binary,p['indices'])]
        for n in normals:normal_error=max(normal_error,abs(sum(v*v for v in n)-1))
        for at in range(0,len(indices),3):
            a,b,c=indices[at:at+3]
            normal=(Vector(positions[b])-Vector(positions[a])).cross(Vector(positions[c])-Vector(positions[a]))
            assert normal.length_squared>1e-15,(path.name,'degenerate exported triangle')
            assert normal.normalized().dot(Vector(normals[a]))>0,(path.name,'exported winding/normal disagreement')
            assert (Vector(normals[a])-Vector(normals[b])).length<1e-5 and (Vector(normals[a])-Vector(normals[c])).length<1e-5,(path.name,'non-flat exported triangle normals')
        all_positions.extend(positions)
    low=[min(p[a] for p in all_positions) for a in range(3)];high=[max(p[a] for p in all_positions) for a in range(3)]
    assert error<3e-5 and normal_error<1e-5
    assert abs(low[1])<1e-6
    assert triangles <= (4500 if path.stem.startswith('tree') else 800),(path.name,triangles)
    return {'file':path.name,'bytes':len(raw),'triangles':triangles,'mesh_names':names,'materials':len(doc['materials']),
            'bounds_gltf_min':low,'bounds_gltf_max':high,'max_linear_color_error':error,'max_unit_normal_error':normal_error,
            'opaque_single_sided':True,'textures':0,'collision_embedded':False,'sha256':hashlib.sha256(raw).hexdigest(),'validation':'PASS'}


def export_assets(assets):
    manifest={'version':3,'status':'Original authored assets; awaiting user art review','source':'forest_canopy_v3.blend',
              'units':'metres','origin':'local bottom centre at trunk / rooted shrub','axis':'Blender Z-up to glTF Y-up once at export',
              'surface':'Opaque closed leaf volumes; flat normals; linear COLOR_0; no bitmap textures or cutout cards',
              'reference':'New user gameplay screenshot informed mass/leaf scale; no reference geometry or imagery copied.',
              'v2_preserved':True,'assets':{}}
    for name,data in assets.items():
        objects=data['objects'];audits=[mesh_audit(o) for o in objects]
        bpy.ops.object.select_all(action='DESELECT')
        for i,o in enumerate(objects):o.name='Bark' if len(objects)==2 and i==0 else 'Leaves';o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,
            export_yup=True,export_normals=True,export_materials='EXPORT',export_animations=False,export_cameras=False,export_lights=False)
        exported=glb_audit(OUT/(name+'.glb'))
        positions=[v.co[:] for o in objects for v in o.data.vertices]
        entry={k:v for k,v in data.items() if k!='objects'}
        entry.update({'source_mesh_checks':audits,'export':exported,
            'bounds_blender_min':[min(p[a] for p in positions) for a in range(3)],
            'bounds_blender_max':[max(p[a] for p in positions) for a in range(3)]})
        manifest['assets'][name]=entry
        for o in objects:o.name=name+'__'+o.name
    return manifest


def look_at(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def diagnostic(assets):
    scene=bpy.context.scene
    offsets={'tree_oak_a':(-2.45,.2,0),'tree_oak_b':(2.20,.20,0),'shrub_leaf':(.80,-2.65,0),'shrub_fern':(-1.40,-2.8,0)}
    for name,data in assets.items():
        for o in data['objects']:o.location=offsets[name]
    scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True
    scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.45,.56,.65,1);bg.inputs['Strength'].default_value=.35
    bpy.ops.mesh.primitive_plane_add(size=100,location=(0,0,-.012))
    ground=bpy.context.object;ground.name='DIAGNOSTIC_Ground_ExcludedFromExport'
    material=bpy.data.materials.new('DIAGNOSTIC_NeutralBackdrop');material.use_nodes=True
    material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.045,.055,.045,1)
    material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.95
    ground.data.materials.append(material)
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,9));key=bpy.context.object
    key.name='DIAGNOSTIC_WarmKey';key.data.energy=700;key.data.size=5;key.data.color=(1,.93,.80);look_at(key,(0,0,2))
    bpy.ops.object.light_add(type='AREA',location=(4,3,6));fill=bpy.context.object
    fill.name='DIAGNOSTIC_CoolFill';fill.data.energy=300;fill.data.size=5;fill.data.color=(.73,.85,1);look_at(fill,(0,0,2))
    bpy.ops.object.camera_add(location=(8,-13,11));cam=bpy.context.object
    cam.name='DIAGNOSTIC_GameplayElevatedAngle';look_at(cam,(0,0,2.0));cam.data.type='ORTHO';cam.data.ortho_scale=11.8;scene.camera=cam
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(HERE/'diagnostic_v3.png')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'forest_canopy_v3.blend'))
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene;scene.name='Original_Forest_Canopy_V3_Study';scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    collection=bpy.data.collections.new('ORIGINAL_V3_ReusableAssets_NotApproved');scene.collection.children.link(collection)
    mats={'leaf':colored_material('ForestV3_Leaf_VertexColor'),'bark':colored_material('ForestV3_Bark_VertexColor'),'fern':colored_material('ForestV3_Fern_VertexColor')}
    write_import_contract()
    assets=trees(collection,mats);assets.update(shrubs(collection,mats))
    manifest=export_assets(assets)
    for path in (HERE/'manifest.json',OUT/'manifest.json'):path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('FOREST_V3_EXPORTS '+json.dumps({name:d['export'] for name,d in manifest['assets'].items()}))
    diagnostic(assets)
    print('FOREST_V3_COMPLETE')


if __name__=='__main__':main()
