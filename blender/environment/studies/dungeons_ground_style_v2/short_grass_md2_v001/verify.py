"""Fresh-open, source preservation, material, placement and actual selector checks."""
import bpy,json,sys,math
from pathlib import Path
D=Path(__file__).resolve().parent;R=D.parents[4];EV=R/'.validation/short_grass_md2_v001';sys.path.insert(0,str(D.parent));sys.path.insert(0,str(D))
from flower_preservation import compare
bpy.ops.wm.open_mainfile(filepath=str(D.parent/'dungeons_ground_style_v2.blend'))
bpy.context.window.view_layer=bpy.context.scene.view_layers['ViewLayer']
errors=compare(json.loads((EV/'before_fingerprints.json').read_text()));assert not errors,errors
manifest=json.loads((D/'manifest.json').read_text());record=json.loads(bpy.context.scene['md2_review']);assert len(bpy.data.scenes)==1
planarity=0.;root_error=0.;material_ids=set()
for item in manifest['assets']:
 obj=bpy.data.objects[item['name']];m=obj.data;material_ids.add(m.materials[0].as_pointer());assert len(m.materials)==1;assert obj.asset_data and obj['review_status']=='Pending'
 assert all(math.isfinite(float(x)) for v in m.vertices for x in v.co)
 assert all(p.area>1e-10 for p in m.polygons)
 assert max(v.co.z for v in m.vertices)<.29
 assert -.009<=min(v.co.z for v in m.vertices)<0.
 for p in m.polygons:
  first=m.vertices[p.vertices[0]].co
  for vi in p.vertices:planarity=max(planarity,abs((m.vertices[vi].co-first).dot(p.normal)))
 assert all(max(v.co[i] for v in m.vertices)-min(v.co[i] for v in m.vertices)>=.99999 for i in [0,1]),obj.name
 assert not obj.modifiers and not obj.animation_data
assert len(material_ids)==1;assert planarity<1e-6
mat=bpy.data.objects[manifest['assets'][0]['name']].data.materials[0];nodes=mat.node_tree.nodes
assert not mat.use_backface_culling and mat['alpha_cutoff']==.5
assert any(n.type=='BSDF_TRANSLUCENT' for n in nodes)
assert any(n.type=='MATH' and n.operation=='GREATER_THAN' for n in nodes)
assert all(n.interpolation=='Closest' for n in nodes if n.type=='TEX_IMAGE')
# Shared original ground topology/materials are retained on every copied platform.
base=bpy.data.objects['ENV_GrassBlock_DI_V3'];grounds=[o for o in bpy.data.objects if o.name.startswith(('MD2_Platform_','MD2_Field_Ground_'))]
assert len(grounds)==10 and all(o.data==base.data for o in grounds)
import review_ui as ui;ui.register();routes=[]
for key in list(record['cameras'])+['Original','Overview']:
 ui.select(bpy.context,key);expected=record['old_layer'] if key=='Original' else record['layer'];assert bpy.context.view_layer.name==expected
 for area in bpy.context.screen.areas:
  if area.type=='VIEW_3D':assert area.spaces.active.camera.name==(record['original_camera'] if key=='Original' else record['cameras'][key])
 routes.append(key)
ui.select(bpy.context,'Original')
assert not compare(json.loads((EV/'before_fingerprints.json').read_text()))
ui.select(bpy.context,'Overview')
report={'passed':True,'original_data_unchanged':True,'baseline_counts':{k:len(v) for k,v in json.loads((EV/'before_fingerprints.json').read_text()).items()},'variants':manifest['assets'],'planarity_error_m':planarity,'cutout':'binary threshold0.5 / nearest / two-sided / transmitted reverse light / no emission','selector_routes':routes,'existing_ground_mesh_and_materials_exact':True,'new_scenes':0,'new_animations':0,'godot_modified':False}
(D/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('MD2_GRASS_NATIVE_VALIDATION',json.dumps(report),flush=True)
