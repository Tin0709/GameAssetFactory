"""Fresh-open content preservation, authorized short-Z change, geometry and UI."""
import bpy,json,sys,math
from pathlib import Path
D=Path(__file__).resolve().parent;R=D.parents[4];E=R/'.validation/tall_grass_md2_v001';sys.path[:0]=[str(D.parent),str(D)]
from flower_preservation import compare,mesh_content
from geometry import check_short_height_and_preservation,asset_record
path=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else D.parent/'dungeons_ground_style_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene;manifest=json.loads((D/'manifest.json').read_text());structure=json.loads((E/'before_structure.json').read_text())
assert scene.name==structure['scene'] and len(bpy.data.scenes)==1 and not bpy.data.actions
assert scene['md2_review']==structure['old_md2_registry'] and scene.camera.name==structure['original_scene_camera']
short_before=json.loads((E/'before_short_meshes.json').read_text());baseline=json.loads((E/'before_fingerprints.json').read_text())
error=check_short_height_and_preservation(scene,baseline,short_before,compare,mesh_content,bpy)
for name,data in structure['collections'].items():
 c=bpy.data.collections[name];assert c.hide_viewport==data['hide_viewport'] and c.hide_render==data['hide_render'];assert sorted(o.name for o in c.objects)==sorted(data['objects'])
 extras={'MD2_Tall_Grass_v001_PENDING'} if name=='Vegetation_Grass_Pending' else set()
 assert set(o.name for o in c.children)==set(data['children'])|extras,name
records=[];mat_ids=set();planarity=0.
for entry in manifest['assets']:
 o=bpy.data.objects[entry['name']];m=o.data;assert o.asset_data and o['review_status']=='Pending';assert not o.modifiers and not o.animation_data;assert tuple(o.scale)==(1.,1.,1.)
 assert all(math.isfinite(float(x)) for v in m.vertices for x in v.co);assert all(p.area>1e-10 for p in m.polygons)
 mat=m.materials[0];mat_ids.add(mat.as_pointer());im=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');r=asset_record(o,im);records.append(r)
 assert .70<=r['visible_height']<=.96 and r['materials']==1 and -.009<=r['root_z']<0
 if '_v001_' in o.name:assert min(r['visible_xy_size'])>=1. and max(r['root_xy_size'])<1.05
 for p in m.polygons:
  co=m.vertices[p.vertices[0]].co
  for vi in p.vertices:planarity=max(planarity,abs((m.vertices[vi].co-co).dot(p.normal)))
assert len(mat_ids)==1 and planarity<1e-6
nodes=mat.node_tree.nodes;assert not mat.use_backface_culling and mat['alpha_cutoff']==.5;assert all(n.interpolation=='Closest' for n in nodes if n.type=='TEX_IMAGE');assert {im.pixels[i] for i in range(3,len(im.pixels),4)}=={0.,1.}
short_records=[]
for name in short_before:
 o=bpy.data.objects[name];im=next(n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE');r=asset_record(o,im);assert abs(r['visible_height']-.5)<1e-6 and min(r['visible_xy_size'])>=1.;short_records.append(r)
import tall_review_ui as ui;ui.register();routes=[];info=ui.record()
for key in list(info['cameras'])+['Short','Original','Overview']:
 ui.select(bpy.context,key)
 expected=info['short_layer'] if key=='Short' else info['original_layer'] if key=='Original' else info['layer'];assert bpy.context.view_layer.name==expected
 assert scene.camera.name==structure['original_scene_camera'];routes.append(key)
assert all(bpy.data.objects[n].data==bpy.data.objects['ENV_GrassBlock_DI_V3'].data for n in bpy.data.objects.keys() if n.startswith(('Tall_MD2_Platform_','Tall_MD2_ClusterBase_','Tall_MD2_FieldGround_','Tall_MD2_CompareBase_')))
report={'passed':True,'source_path':str(path),'original_data_preserved_except_explicit_short_z':True,'original_object_count':structure['objects'],'original_actions':0,'short_z_formula_error_m':error,'short_grass_height_update':short_records,'tall_assets':records,'max_quad_planarity_error_m':planarity,'selector_routes':routes,'new_scenes':0,'new_actions':0,'asset_materials':1,'atlas_size':[128,128],'godot_integration':False,'mobile_claim':'geometry/material budget only; no phone benchmark'}
(D/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('TALL_NATIVE_VALIDATION',json.dumps(report),flush=True)
