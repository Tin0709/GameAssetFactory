"""Foreground-only six-module plus assembly and separated review displays."""
import bpy,bmesh,json,sys
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Live source editing only'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
from validate_leaf_plus_6blocks_v1 import CELLS,DIRECTIONS,audit_assembly
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
base=json.loads((EVIDENCE/'before_leaf_plus_assembly_fingerprints.json').read_text());assert not compare(base['data'])
assert not bpy.data.objects.get('ENV_LeafCluster_Plus_6Blocks_V1')
# Existing library/rest meshes are never altered: only review translations separate enlarged sprigs.
locations={}
for name,fields in base['display_fields'].items():
    obj=bpy.data.objects[name];delta=.6 if name.startswith(('ENV_LeafBlock_1m_V1_B','REVIEW_LeafModule_B_'))else 1.2 if name.startswith(('ENV_LeafBlock_1m_V1_C','REVIEW_LeafModule_C_'))else 1.8
    if obj.parent:delta=0
    obj.location.x+=delta;locations[name]=list(obj.location)
collection=bpy.data.collections.new('LEAF_CLUSTER_Plus_6Blocks_V1');bpy.context.scene.collection.children.link(collection)
root=bpy.data.objects.new('ENV_LeafCluster_Plus_6Blocks_V1',None);collection.objects.link(root);root.location=(36,3.2,0);root['study_only']=True;root['structural_core_m']=[3,3,2]
occupied=set(CELLS);specs=[]
def filtered_copy(source,name,attribute,blocked,core=False):
    mesh=source.copy();mesh.name=name;bm=bmesh.new();bm.from_mesh(mesh);layer=bm.faces.layers.int[attribute];part=bm.faces.layers.int.get('leaf_part')
    remove=[f for f in bm.faces if f[layer]in blocked and(not core or f[part]==0)];bmesh.ops.delete(bm,geom=remove,context='FACES');orphans=[v for v in bm.verts if not v.link_faces]
    if orphans:bmesh.ops.delete(bm,geom=orphans,context='VERTS')
    bm.to_mesh(mesh);bm.free();mesh.update();return mesh
for i,(cell,variant)in enumerate(zip(CELLS,('A','B','C','A','C','B'))):
    blocked=[side for side,d in enumerate(DIRECTIONS)if tuple(cell[k]+d[k]for k in range(3))in occupied];source=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant]
    mesh=filtered_copy(source.data,'ENV_LeafCluster_Plus_Cell_'+str(i)+'_OuterCore','core_face',blocked,True);obj=bpy.data.objects.new('ENV_LeafCluster_Plus_Cell_'+str(i),mesh);collection.objects.link(obj);obj.parent=root;obj.location=cell;obj['source_variant']=variant;obj['internal_faces_removed']=blocked
    srcbranch=bpy.data.objects[source.name+'_CrossBranches'];branchmesh=filtered_copy(srcbranch.data,'ENV_LeafCluster_Plus_Cell_'+str(i)+'_OuterBranches','branch_side',blocked)if any(side<5 for side in blocked)else srcbranch.data
    branch=bpy.data.objects.new(obj.name+'_CrossBranches',branchmesh);collection.objects.link(branch);branch.parent=obj
    specs.append({'cell':cell,'variant':variant,'object':obj.name,'branch_object':branch.name,'blocked_sides':blocked})
# Neutral separate floor and1m metre grid; no new lighting/camera architecture.
fm=bpy.data.meshes.new('REVIEW_LeafPlus_StudioFloor');fm.from_pydata([(33.5,.8,-.012),(40.5,.8,-.012),(40.5,5.7,-.012),(33.5,5.7,-.012)],[],[(0,1,2,3)]);fm.materials.append(bpy.data.materials['MAT_LeafModule_StudioFloor']);floor=bpy.data.objects.new(fm.name,fm);collection.objects.link(floor);floor['display_only']=True
# Extension beneath separated library actor, independent of the preserved original floor.
em=fm.copy();em.name='REVIEW_LeafModules_FloorExtension';em.clear_geometry();em.from_pydata([(31.8,1.8,-.012),(33.4,1.8,-.012),(33.4,4.7,-.012),(31.8,4.7,-.012)],[],[(0,1,2,3)]);eo=bpy.data.objects.new(em.name,em);bpy.data.collections['LEAF_MODULES_1Block_V1'].objects.link(eo)
rig=bpy.data.objects['REVIEW_LeafModules_R15_Rest_Rig'].copy();rig.data=rig.data.copy();rig.name='REVIEW_LeafPlus_R15_Rest_Rig';collection.objects.link(rig);rig.location=(39.2,3.2,0)
actor=bpy.data.objects['REVIEW_LeafModules_R15_Rest_1p8m'].copy();actor.name='REVIEW_LeafPlus_R15_Rest_1p8m';collection.objects.link(actor);actor.parent=rig
for modifier in actor.modifiers:
    if modifier.type=='ARMATURE':modifier.object=rig
for i in range(-2,3):
    gm=bpy.data.meshes.new('REVIEW_LeafPlus_Metre_'+str(i));gm.from_pydata([(36+i,.8,-.009),(36+i+.012,.8,-.009),(36+i+.012,5.7,-.009),(36+i,5.7,-.009)],[],[(0,1,2,3)]);o=bpy.data.objects.new(gm.name,gm);collection.objects.link(o)
label=bpy.data.objects['REVIEW_LeafModule_A_Label'].copy();label.data=label.data.copy();label.name='REVIEW_LeafPlus_Grid_Label';collection.objects.link(label);label.location=(34.3,1.05,.015);label.data.size=.13;label.data.body='PLUS CLUSTER / SIX 1 m MODULES\nCORE 3 x 3 x 2 m / R15 REST 1.8 m'
manifest={'status':'New user-requested plus assembly; pending artistic review; older bulk remains frozen','cells':specs,'structural_core_m':[3,3,2],'placement':'Five lower blocks in plus/cross and one upper centre,1m steps','internal_treatment':'Assembly-only copied cores omit occupied-neighbour core sides; copied branch sides omitted at occupied neighbours. Library geometry/materials unchanged. Exposed branch planes retain2xscale.','display_locations':locations,'display_root':[36,3.2,0],'scope':'Blender only, no game export/integration'}
(HERE/'leaf_plus_6blocks_v1_manifest.json').write_text(json.dumps(manifest,indent=2));bpy.context.view_layer.update();report=audit_assembly();manifest['audit']=report;(HERE/'leaf_plus_6blocks_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
root.select_set(True);bpy.context.view_layer.objects.active=root
for window in bpy.context.window_manager.windows:
    for area in window.screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(36.5,3.2,1);space.region_3d.view_distance=7;space.region_3d.view_rotation=(Vector((36.5,3.2,1))-Vector((42,-3,5))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'Six-block plus cluster visible/saved LIVE; original module geometry preserved','audit':report}
