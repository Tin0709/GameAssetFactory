"""Reopen actual library/stage, exercise selector and inspect source preservation."""
import bpy,json,sys,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[6];OUT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/characters/soldier/showcase'));sys.path.insert(0,str(R/'blender/animation/showcase'))
import soldier_library_ui as ui
import gaf_animation_library as animation
baseline=json.loads((R/'.validation/sword_combo_original_v001_20261025/soldier_native_baseline.json').read_text())
for name,h in baseline['meshes'].items():
 m=bpy.data.meshes[name];value=hashlib.sha256(repr(([tuple(v.co) for v in m.vertices],[(tuple(p.vertices),p.material_index) for p in m.polygons],[[tuple(d.uv) for d in l.data] for l in m.uv_layers])).encode()).hexdigest();assert value==h,('original mesh changed',name)
for name,h in baseline['actions'].items():
 a=bpy.data.actions[name];value=hashlib.sha256()
 for l in a.layers:
  for st in l.strips:
   for bag in st.channelbags:
    for c in bag.fcurves:value.update(repr((c.data_path,c.array_index,[(tuple(k.co),k.interpolation) for k in c.keyframe_points])).encode())
 assert value.hexdigest()==h,('original Action changed',name)
for name,d in baseline['objects'].items():
 if d['type']=='ARMATURE':
  o=bpy.data.objects[name]
  assert {b.name:list(map(list,b.matrix_local)) for b in o.data.bones}=={n:v['matrix'] for n,v in d['bones'].items()},('original rig changed',name)

ui.register();tests={}
for key in ['SOLDIER_Skin_v001','SOLDIER_Backpack_v001','SOLDIER_Facial_System_v001','SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001','SOLDIER_Sword_Combo_v001']:
 result=bpy.ops.soldier_library.select_asset(asset_id=key);tests[key]=result=={'FINISHED'}
 assert tests[key],(key,result)
for mode,f in [('RESTART',1),('HIT1',10),('HIT2',25),('HIT3',43)]:
 assert bpy.ops.soldier_library.animation_control(mode=mode)=={'FINISHED'}
 assert bpy.context.scene.frame_current==f
for direction in ['Front','Front_3Q','Left_Side','Back','Right_Side','Back_3Q']:
 assert bpy.ops.soldier_library.view(direction=direction)=={'FINISHED'}
 assert bpy.context.scene.camera.name=='SW_'+direction
s=bpy.context.scene;r=bpy.data.objects['SW_Soldier_Review_Rig'];a=r.animation_data.action
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());entry=next(e for e in manifest['animations'] if e['action']==a.name)
assert animation.action_signature(a)==entry['action_sha256']
assert animation.rest_signature(r.data)==manifest['rig_sha256']
# Dense native evaluation includes both 30 FPS frames and 60 FPS half-frames.
body=bpy.data.objects['SW_Body'];floor=99;max_scale=0
from mathutils import Vector
for j in range(121):
 f=1+j/2;s.frame_set(int(f),subframe=f-int(f));deps=bpy.context.evaluated_depsgraph_get();e=body.evaluated_get(deps);m=e.to_mesh()
 ids=[v.index for v in body.data.vertices if any(body.vertex_groups[w.group].name.startswith('Leg.') for w in v.groups)]
 floor=min(floor,min(m.vertices[i].co.z for i in ids));e.to_mesh_clear()
 max_scale=max(max_scale,max(abs(v-1) for b in r.pose.bones for v in b.scale))
assert floor>=-.001 and max_scale<1e-6
report={'passed':True,'selectors':tests,'views':6,'contact_frame_controls':[10,25,43],'fps_checked':[30,60],'lowest_body_sole_m':floor,'canonical_action_hash_matches':True,'old_meshes_uvs_material_indices_preserved':len(baseline['meshes']),'old_action_curves_preserved':len(baseline['actions']),'old_rig_rest_transforms_preserved':True,'godot_integrated':False}
(OUT/'soldier_preview_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SOLDIER_PREVIEW_VERIFIED',json.dumps(report),flush=True)
