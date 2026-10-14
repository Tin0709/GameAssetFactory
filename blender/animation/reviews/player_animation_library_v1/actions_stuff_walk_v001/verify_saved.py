import bpy,json,sys,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as lib
old=json.loads((HERE/'library_preservation.json').read_text());info=json.loads((HERE/'manifest.json').read_text())
assert len(bpy.data.actions)==old['new_action_count']==327
assert all(lib.action_signature(bpy.data.actions[n])==v for n,v in old['old_actions'].items())
assert all(lib.rest_signature(bpy.data.armatures[n])==v for n,v in old['old_rigs'].items())
for n,digest in old['old_meshes'].items():
 m=bpy.data.meshes[n];value=hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight)for g in v.groups])for v in m.vertices],[(tuple(p.vertices),p.material_index)for p in m.polygons],[[tuple(v.uv)for v in l.data]for l in m.uv_layers])).encode()).hexdigest();assert value==digest,n
assert json.loads(bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1']['review_catalog'])[:-1]==old['old_catalog']
exec(bpy.data.texts['START_HERE_review_controls.py'].as_string(),{'__name__':'asw_verification_controls'})
for id in ['4','asw_walk_source_v001','0','asw_walk_source_v001']:
 assert bpy.ops.player_review.select(clip_id=id)=={'FINISHED'}
s=bpy.context.scene;r=bpy.data.objects[info['source_rig']];a=r.animation_data.action
assert a.name==info['action'] and lib.action_signature(a)==info['action_sha256']
assert s.frame_start==1 and s.frame_end==24 and s.render.fps==30 and r.animation_data.action_slot==a.slots[0]
s.frame_set(1);first={p.name:p.matrix.copy() for p in r.pose.bones};s.frame_set(25)
seam=max(abs(p.matrix[i][j]-first[p.name][i][j])for p in r.pose.bones for i in range(4)for j in range(4));assert seam<2e-6
report={'fresh_saved_library_reopened':True,'prior_actions_preserved':len(old['old_actions']),'prior_armatures_preserved':len(old['old_rigs']),'prior_meshes_uv_weights_preserved':len(old['old_meshes']),'prior_catalog_entries_preserved':len(old['old_catalog']),'new_action_count':len(bpy.data.actions),'selection_transitions':4,'slot_bound':True,'playback':[1,24],'closing_key':25,'fps':30,'loop_pose_seam_error':seam}
(HERE/'saved_library_verification.json').write_text(json.dumps(report,indent=2));print('SAVED_LIBRARY_VERIFIED',json.dumps(report))
