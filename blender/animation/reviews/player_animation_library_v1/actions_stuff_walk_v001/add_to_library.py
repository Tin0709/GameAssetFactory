"""Add the one new walking study, preserving every existing library Action."""
import bpy,json,sys,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as lib
info=json.loads((HERE/'manifest.json').read_text());target=HERE.parent/'player_animation_library_v1.blend'
records=json.loads(Path('/tmp/codex-player-walk-01a1399a/baseline_files.json').read_text());relative=target.relative_to(ROOT).as_posix()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(target)==records[relative]['sha256'],'Library changed concurrently'
old_actions={a.name:lib.action_signature(a) for a in bpy.data.actions}
old_rigs={a.name:lib.rest_signature(a) for a in bpy.data.armatures}
old_meshes={m.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight)for g in v.groups])for v in m.vertices],[(tuple(p.vertices),p.material_index)for p in m.polygons],[[tuple(v.uv)for v in l.data]for l in m.uv_layers])).encode()).hexdigest() for m in bpy.data.meshes}
master=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1'];catalog=json.loads(master['review_catalog']);old_catalog=list(catalog)
assert info['action'] not in bpy.data.actions
with bpy.data.libraries.load(str(HERE/'walk_actions_stuff_review.blend'),link=False) as (src,dst):dst.scenes=[info['scene']]
sc=dst.scenes[0];rig=next(o for o in sc.objects if o.type=='ARMATURE');mesh=next(o for o in sc.objects if o.name.startswith('ASW_Player_Mesh'))
a=bpy.data.actions[info['action']];a.use_fake_user=True
assert lib.action_signature(a)==info['action_sha256'];assert lib.rest_signature(rig.data)==info['rig_sha256']
cameras={k:next(o.name for o in sc.objects if o.type=='CAMERA' and o.name.startswith(v)) for k,v in [('FRONT','Showcase_FRONT'),('SIDE','Showcase_SIDE'),('THREE_QUARTER','Showcase_THREE_QUARTER')]};cameras['BACK']=cameras['FRONT'];sc['review_cameras']=json.dumps(cameras)
sc.camera=bpy.data.objects[cameras['THREE_QUARTER']]
entry={'id':'asw_walk_source_v001','label':'Walking / Actions & Stuff source v001 [Pending]','group':'Locomotion','actor':None,'scene':sc.name,'action':a.name,'review_rig':rig.name,'start':1,'end':24,'fps':30,'duration_seconds':0.8,'status':'Pending human review','review_note':'Actions & Stuff walking / native rigid rig','phase_note':'24 frames / 0.8 s; closing F25 excluded','carrier_note':'In place / no gameplay export','source':str((HERE/'walk_actions_stuff_review.blend').relative_to(ROOT))}
catalog.append(entry);master['review_catalog']=json.dumps(catalog);master['review_selected']=entry['id']
bpy.context.window.scene=sc;sc.frame_start=1;sc.frame_end=24;sc.render.fps=30;sc.frame_set(1)
bpy.context.view_layer.objects.active=rig
for o in bpy.context.selected_objects:o.select_set(False)
rig.select_set(True)
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False
assert all(lib.action_signature(bpy.data.actions[n])==v for n,v in old_actions.items())
assert all(lib.rest_signature(bpy.data.armatures[n])==v for n,v in old_rigs.items())
assert catalog[:-1]==old_catalog
assert sha(target)==records[relative]['sha256'],'Library changed before save'
bpy.ops.wm.save_as_mainfile(filepath=str(target))
manifest_path=HERE.parent/'review_manifest.json';old_manifest=json.loads(manifest_path.read_text());assert old_manifest['catalog']==old_catalog
old_manifest['catalog']=catalog;old_manifest['catalog_entries']=len(catalog);old_manifest['total_actions']=len(bpy.data.actions);old_manifest['default_review']=entry['id'];old_manifest['actions_stuff_walk_v001']={**info,'source_blend_sha256':sha(HERE/'walk_actions_stuff_review.blend'),'entry':entry}
manifest_path.write_text(json.dumps(old_manifest,indent=2))
verification={'prior_action_count':len(old_actions),'new_action_count':len(bpy.data.actions),'prior_actions_preserved':True,'prior_rest_rigs_preserved':True,'prior_catalog_entries_preserved':True,'catalog_entries':len(catalog),'action_sha256':lib.action_signature(a),'old_actions':old_actions,'old_rigs':old_rigs,'old_meshes':old_meshes,'old_catalog':old_catalog,'entry':entry}
(HERE/'library_preservation.json').write_text(json.dumps(verification,indent=2))
print('LIBRARY_UPDATED',json.dumps({k:v for k,v in verification.items() if k not in ['old_actions','old_rigs','old_meshes','old_catalog']}))
