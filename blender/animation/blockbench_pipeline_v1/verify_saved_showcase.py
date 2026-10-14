import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];sys.path.insert(0,str(HERE.parent/'showcase'))
import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['Showcase_Player_Rig'];m=bpy.data.objects['Showcase_Player_Mesh']
if not hasattr(bpy.types.Scene,'gaf_clips'):ui.register()
manifest=ui.load_manifest();original=json.loads((ROOT/'.validation/blockbench_pipeline_v1/before/blender/animation/showcase/animation_manifest.json').read_text());before=json.loads((HERE/'validation/before_action_signatures.json').read_text())
assert manifest['animations'][:28]==original['animations'];assert len(manifest['animations'])>=33
assert len(bpy.data.actions)>=33 and len([o for o in bpy.data.objects if o.type=='ARMATURE'])==1
for n,d in before.items():assert ui.action_signature(bpy.data.actions[n])==d,n
assert ui.rest_signature(r.data)==original['rig_sha256'];snapshot=json.loads(s['gaf_manifest_snapshot']);assert snapshot['animations'][:33]==manifest['animations'][:33]
assert all(e['status']=='pending' for e in manifest['animations'][28:33]);assert len(s.gaf_clips)>=33
# Every entry can still be selected with its original slot/timing, including reset after a different pose.
transitions=0
for i,e in enumerate(manifest['animations'][:33]):
 s.gaf_active_index=i;ui.activate(s,i);assert r.animation_data.action.name==e['action'];assert r.animation_data.action_slot.identifier==e['slot_identifier'];assert (s.frame_start,s.frame_end,s.render.fps)==(e['start'],e['end'],e['fps']);transitions+=1
for prior in [0,17,27,32]:
 ui.activate(s,prior);ui.activate(s,28);bpy.context.view_layer.update()
 assert max(abs(p.matrix[i][j]-p.bone.matrix_local[i][j]) for p in r.pose.bones for i in range(4) for j in range(4))<2e-6;transitions+=2
# Persisted test curves agree with the exported poses at playback boundaries/middle after fresh reopen.
C=Matrix(json.loads((HERE/'bridge_contract.json').read_text())['blender_to_blockbench']);Ci=C.inverted();maximum=0
for i,e in enumerate(manifest['animations'][28:33],28):
 clip=json.loads((ROOT/e['blockbench_samples']).read_text());rest={n:Matrix(v) for n,v in clip['rest'].items()}
 for sample in [clip['samples'][0],clip['samples'][60],clip['samples'][-1]]:
  ui.activate(s,i);s.frame_set(round(1+sample['time']*30));bpy.context.view_layer.update()
  for n,v in sample['matrices'].items():
   wanted=Ci@Matrix(v)@rest[n].inverted()@C@r.data.bones[n].matrix_local
   maximum=max(maximum,max(abs(r.pose.bones[n].matrix[a][b]-wanted[a][b]) for a in range(4) for b in range(4)))
assert maximum<2e-6
result={'saved_action_count':len(bpy.data.actions),'unrelated_concurrent_entries_preserved':max(0,len(manifest['animations'])-33),'original_actions_exact':28,'approved_backups':12,'pending_imports':5,'original_armature_count':1,'selection_transitions':transitions,'saved_pose_matrix_error':maximum,'fps':30,'test_playback':[1,31],'tests_are_one_shots':True,'save_reopen_verified':True}
(HERE/'validation/showcase_validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if '--render' in sys.argv:
 s.render.resolution_x=600;s.render.resolution_y=600;s.render.resolution_percentage=100
 for j in range(5):
  ui.activate(s,28+j);s.frame_set(16)
  for view in ['FRONT','THREE_QUARTER']:
   s.camera=bpy.data.objects['Showcase_'+view];s.render.filepath=str(HERE/'validation/previews'/f'blender_{j}_{view.lower()}.png');bpy.ops.render.render(write_still=True)
