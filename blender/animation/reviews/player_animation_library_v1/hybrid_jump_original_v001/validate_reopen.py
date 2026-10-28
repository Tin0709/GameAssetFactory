import bpy,json,sys,hashlib,runpy
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[4];LIB=R/'blender/animation/showcase';sys.path.insert(0,str(H));import motion as m
runpy.run_path(str(R/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
B=R/'.validation/animation_showcase/hybrid_jump_original_v001';base=json.loads((B/'baseline.json').read_text(encoding='utf8'));old=json.loads((B/'animation_manifest.json').read_text(encoding='utf8'));data=json.loads((LIB/'animation_manifest.json').read_text(encoding='utf8'))
assert data['animations'][:72]==old['animations']and data['review_sequences'][:5]==old['review_sequences']
assert len(data['animations'])==76 and len(data['review_sequences'])==6
rig=bpy.data.objects[ui.RIG];checks=[]
for e in data['animations'][72:]:
 assert e['status']=='pending'and not e['source_keyframes_copied'];ui.validate_action(bpy.data.actions[e['action']],e,rig);ui.select_registered_action(bpy.context,e['action'])
 assert rig.animation_data.action.name==e['action']and rig.animation_data.action_slot.identifier==e['slot_identifier']
 s=bpy.context.scene;assert s.frame_start==e['start']and s.frame_end==e['end']and s.render.fps==60 and s.render.fps_base==1
 checks.append({'action':e['action'],'slot':e['slot_identifier'],'range':[e['start'],e['end']]})
# Prove old Pending Walk/Run and approved Idle still select/reset normally.
for name in ['Walk_ASInspired_Original_v001_PENDING','Run_ASInspired_Original_v001_PENDING','Idle_ActionsStuff_Source_Test_v001']:
 ui.select_registered_action(bpy.context,name);assert rig.animation_data.action.name==name
e=data['review_sequences'][-1];ui.validate_review_sequence(e);ui.open_review_sequence(bpy.context,e['id']);s=bpy.context.scene;s.gaf_loop=True
for d in ['FRONT','SIDE','THREE_QUARTER']:ui.view(s,d);assert s.camera.name==e['cameras'][d]
carrier=bpy.data.objects[e['world_root']];samples=[]
for t in [0,m.START,m.START+m.APEX_TIME,m.START+m.FLIGHT,m.DURATION]:
 f=1+t*60;s.frame_set(int(f),subframe=f%1);err=abs(carrier.location.z-m.elevation(t));assert err<1e-5,err;samples.append({'time_s':t,'height_m':carrier.location.z})
changed=[p for p,digest in base['godot'].items()if hashlib.sha256((R/p).read_bytes()).hexdigest()!=digest];assert not changed,changed
assert ui.rest_signature(rig.data)==data['rig_sha256']and s.sync_mode=='FRAME_DROP'
s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(LIB/'Animation_Showcase.blend'))
(H/'reopen_validation.json').write_text(json.dumps({'old_registry_entries_preserved':72,'old_reviews_preserved':5,'total_actions':len(bpy.data.actions),'new_pending_actions':checks,'unchanged_godot_files':len(base['godot']),'godot_changes':changed,'cameras_checked':3,'actual_presentation_samples':samples,'sync_mode':s.sync_mode},indent=2),encoding='utf8')
print('JUMP_REOPEN_VALIDATED',len(checks),len(base['godot']),flush=True)
