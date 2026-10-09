"""Live-only reusable open leaf cubes: opaque geometric patches, no solid/background cards."""
import bpy,json,sys,random,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Author only in the current foreground Blender window'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_leaf_modules_fingerprints.json').read_text());assert not compare(baseline['data'])
assert not bpy.data.collections.get('LEAF_MODULES_1Block_V1')
collection=bpy.data.collections.new('LEAF_MODULES_1Block_V1');bpy.context.scene.collection.children.link(collection)
palette=['324420','435222','59642b','687333','78853b','859344','3c4b1f'];rgba=[tuple(int(h[k:k+2],16)/255 for k in(0,2,4))+(1,)for h in palette]
mat=bpy.data.materials.new('MAT_LeafModules_V1_OpaqueLinearVertexAlbedo');mat.use_nodes=True;mat.use_backface_culling=False
bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=1;bsdf.inputs['Specular IOR Level'].default_value=0
vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
reports=[]
for variant,x in zip(('A','B','C'),(25.5,27,28.5)):
    rng=random.Random(861319+ord(variant)*907);verts=[];faces=[];colors=[];parts=[];axes=[]
    def quad(points,c,part,axis):
        start=len(verts);verts.extend(tuple(p)for p in points);faces.append(tuple(range(start,start+4)));colors.append(c);parts.append(part);axes.append(axis)
    def core_point(axis,a,b):
        return [(.5,a-.5,b),(-.5,.5-a,b),(.5-a,.5,b),(a-.5,-.5,b),(a-.5,b-.5,1),(a-.5,.5-b,0)][axis]
    cover=[]
    for axis in range(6):
        n=18;grid=[[-1]*n for _ in range(n)]
        while sum(c>=0 for row in grid for c in row)<n*n*.79:
            sx,sy=rng.randrange(n),rng.randrange(n);w,h=rng.randrange(2,5),rng.randrange(1,4);c=rng.choices(range(7),weights=[16,20,19,19,11,5,10])[0]
            for y in range(sy,min(n,sy+h)):
                for a in range(sx,min(n,sx+w)):grid[y][a]=max(0,min(6,c+rng.choices((-1,0,1),weights=[1,8,1])[0]))
        cover.append(sum(c>=0 for row in grid for c in row)/(n*n))
        used=set()
        for y in range(n):
            for a in range(n):
                if (a,y)in used or grid[y][a]<0:continue
                c=grid[y][a];w=1
                while w<2 and a+w<n and grid[y][a+w]==c and (a+w,y)not in used:w+=1
                h=1
                while h<3 and y+h<n and all(grid[y+h][ix]==c and (ix,y+h)not in used for ix in range(a,a+w)):h+=1
                used.update((ix,iy)for ix in range(a,a+w)for iy in range(y,y+h))
                points=[core_point(axis,ix/n,iy/n)for ix,iy in((a,y),(a+w,y),(a+w,y+h),(a,y+h))]
                quad(points,c,0,axis)
    # Blunt stepped leaf sprigs on edge and top planes; all actual holes stay empty.
    shape=[(0,0),(1,0),(1,1),(2,1),(1,2)]
    for i in range(36):
        mode=i%2;top=i<12;fixed=rng.uniform(-.38,.38)if top else rng.choice((-1,1))*(.52+i*.0006)
        start=rng.uniform(-.35,.25)if top else rng.choice((-.58,.46));z=.97 if top else rng.uniform(.08,.73);c=rng.randrange(7)
        for a,b in shape:
            def point(dx,dz):return (start+dx,fixed,z+dz)if mode==0 else(fixed,start+dx,z+dz)
            points=[point(dx*.04,dz*.04)for dx,dz in((a,b),(a+1,b),(a+1,b+1),(a,b+1))]
            quad(points,c if rng.random()>.20 else min(6,c+1),1,-1)
    # Small crossed internal clumps add leafy shadow depth without a solid volume.
    for i in range(12):
        center=Vector((rng.uniform(-.31,.31),rng.uniform(-.31,.31),rng.uniform(.12,.75)));c=rng.randrange(4)
        for mode in (0,1):
            for a,b in shape:
                def point(dx,dz):return center+Vector((dx/18,0,dz/18))if mode==0 else center+Vector((0,dx/18,dz/18))
                quad([point(dx,dz)for dx,dz in((a,b),(a+1,b),(a+1,b+1),(a,b+1))],c,2,-1)
    m=bpy.data.meshes.new('ENV_LeafBlock_1m_V1_'+variant+'_PlanarLeafMesh');m.from_pydata(verts,[],faces);m.materials.append(mat);m.update()
    color=m.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER');part=m.attributes.new(name='leaf_part',type='INT',domain='FACE');axis_attr=m.attributes.new(name='core_face',type='INT',domain='FACE')
    for p,c,kind,axis in zip(m.polygons,colors,parts,axes):
        part.data[p.index].value=kind;axis_attr.data[p.index].value=axis
        for li in p.loop_indices:color.data[li].color_srgb=rgba[c]
    m.color_attributes.active_color=color
    obj=bpy.data.objects.new('ENV_LeafBlock_1m_V1_'+variant,m);collection.objects.link(obj);obj.location=(x,3.2,0)
    obj['authoring_status']='Requested individual reusable1m leaf module; Blender-only art review pending';obj['core_reserved_m']=[1,1,1];obj['foliage_overhang_limit_m']=.1;obj['provenance']='Original seeded opaque geometric pixel leaf patches and actual empty gaps; no copied texture/background alpha card'
    display=obj.location.copy()
    for o in list(bpy.context.selected_objects):o.select_set(False)
    obj.select_set(True);bpy.context.view_layer.objects.active=obj;obj.location=(0,0,0);bpy.context.view_layer.update();path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')
    try:bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_materials='EXPORT',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
    finally:obj.location=display
    reports.append({'variant':variant,'object':obj.name,'core_surface_coverage':cover,'path':'exports/'+path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    # Viewport-only core wire, independent of foliage overhang.
    marker=bpy.data.objects.new('REVIEW_LeafModule_'+variant+'_1m_Core_Wire',None);collection.objects.link(marker);marker.empty_display_type='CUBE';marker.empty_display_size=.5;marker.location=(x,3.2,.5);marker['display_only']=True
    label=bpy.data.objects['REVIEW_TallGolden_Actual_Height_Label'].copy();label.data=label.data.copy();label.name='REVIEW_LeafModule_'+variant+'_Label';collection.objects.link(label);label.location=(x-.55,2.25,.015);label.data.size=.11;label.data.body='LEAF MODULE '+variant+' / 1 m CORE\nOPEN GEOMETRIC LEAVES'
# Neutral studio floor and actual1.8m actor copy, both display only.
floor_mat=bpy.data.materials.new('MAT_LeafModule_StudioFloor');floor_mat.diffuse_color=(.25,.29,.31,1);floor_mat.use_nodes=True;floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.25,.29,.31,1);floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
fm=bpy.data.meshes.new('REVIEW_LeafModules_StudioFloor');fm.from_pydata([(24,1.8,-.012),(31.8,1.8,-.012),(31.8,4.7,-.012),(24,4.7,-.012)],[],[(0,1,2,3)]);fm.materials.append(floor_mat);floor=bpy.data.objects.new(fm.name,fm);collection.objects.link(floor);floor['display_only']=True
rig=bpy.data.objects['Player_Cuboid_Rig'].copy();rig.data=rig.data.copy();rig.name='REVIEW_LeafModules_R15_Rest_Rig';collection.objects.link(rig);rig.location=(30.3,3.2,0)
actor=bpy.data.objects['Player_Cuboid_Base'].copy();actor.name='REVIEW_LeafModules_R15_Rest_1p8m';collection.objects.link(actor);actor.parent=rig
for modifier in actor.modifiers:
    if modifier.type=='ARMATURE':modifier.object=rig
actor['display_only']=True;rig['display_only']=True
# Ground grid marks indicate true metres; no terrain height belongs to the leaf core.
for x in (25,26,27,28,29,30):
    gm=bpy.data.meshes.new('REVIEW_LeafModule_GroundMetre_'+str(x));gm.from_pydata([(x,1.8,-.009),(x+.012,1.8,-.009),(x+.012,4.7,-.009),(x,4.7,-.009)],[],[(0,1,2,3)]);g=bpy.data.objects.new(gm.name,gm);collection.objects.link(g);g['display_only']=True
bpy.context.view_layer.update()
from validate_leaf_modules_v1 import audit_modules
audit=audit_modules();manifest={'status':'Individual1m open leaf modules awaiting review; earlier bulk bush paused/hidden','palette_srgb':['#'+p for p in palette],'geometry':'Opaque geometric pixel leaf clusters with real empty gaps; flat blunt edge/top sprigs; no texture or alpha cards','core_m':[1,1,1],'side_overhang_limit_m':.1,'source_file':'dungeons_ground_style_v2.blend','modules':reports,'audit':audit,'future_assembly':'3×3 blocks and about2m tall is a future assembly target, not these individual block dimensions'}
(HERE/'leaf_modules_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
obj=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];obj.select_set(True);bpy.context.view_layer.objects.active=obj
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.overlay.show_overlays=True;space.overlay.show_floor=False;space.shading.type='MATERIAL';space.shading.use_scene_lights=False;space.shading.use_scene_world=False;space.region_3d.view_location=(27.8,3.2,.8);space.region_3d.view_distance=7.8;space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'Independent open leaf modules A/B/C created and saved LIVE in the same window','audit':audit}
