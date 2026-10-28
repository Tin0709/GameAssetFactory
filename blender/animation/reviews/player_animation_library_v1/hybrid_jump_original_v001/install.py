"""Append only original Jump phases/context to the existing shared Showcase."""
import bpy,sys,json,hashlib,runpy,faulthandler
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[4];LIB=R/'blender/animation/showcase'
sys.path.insert(0,str(H));import motion as m,stage
runpy.run_path(str(R/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
B=R/'.validation/animation_showcase/hybrid_jump_original_v001';base=json.loads((B/'baseline.json').read_text(encoding='utf8'));meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
central=LIB/'Animation_Showcase.blend';manifest=LIB/'animation_manifest.json'
for path,digest in base['files'].items():assert sha(Path(path))==digest,'Concurrent library edit; stop'
data=json.loads(manifest.read_text(encoding='utf8'));native=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];modes={b.name:b.rotation_mode for b in native.pose.bones}
assert set(base['actions'])==set(bpy.data.actions.keys())
with bpy.data.libraries.load(str(H/'hybrid_jump_authoring.blend'),link=False)as(src,dst):dst.actions=meta['actions']
entries=[]
for action,spec in zip(dst.actions,meta['specs']):
 e={'action':action.name,'source':meta['source'],'source_sha256':meta['source_sha256'],'source_rig':meta['rig'],'source_mesh':meta['mesh'],'source_armature':meta['armature'],'slot_identifier':action.slots[0].identifier,'action_sha256':ui.action_signature(action),'action_frame_range':list(action.frame_range),'start':spec['start'],'end':spec['end'],'fps':60,'fps_base':1.,'rotation_modes':modes,'status':'pending','approval_note':'Original MD2-foundation/A&S-inspired Jump. Awaiting human artistic review; no Godot integration.','seamless_loop':spec['loop'],'original_custom_animation':True,'source_keyframes_copied':False,'production_eligible':False,'preview_only':spec.get('preview_only',False),'preview_floor_z_m':spec['floor'],'provenance':'Independent original pose curves; verified source timing/artistic principles only. No reference keys or native physics code copied.','phase':spec['phase'],'phase_duration_s':spec['duration'],'playback_sync':'FRAME_DROP'}
 action.use_fake_user=True;ui.validate_action(action,e,native);entries.append(e)
s,carrier,rig,mesh,pa,cameras,hud=stage.build(native,mesh,bpy.data.actions[entries[-1]['action']],m)
review={'id':'hybrid_jump_original_v001','label':'Original Jump — MD2 foundation + A&S bounce','status':'pending','scene':s.name,'rig':rig.name,'mesh':mesh.name,'world_root':carrier.name,'pose_action':entries[-1]['action'],'pose_slot_identifier':bpy.data.actions[entries[-1]['action']].slots[0].identifier,'pose_action_sha256':entries[-1]['action_sha256'],'presentation_action':pa.name,'presentation_slot_identifier':pa.slots[0].identifier,'presentation_action_sha256':ui.action_signature(pa),'start':1,'end':120,'fps':60,'fps_base':1.,'seamless_loop':False,'research_only':True,'production_eligible':False,'original_authored_comparison':True,'rig_sha256':data['rig_sha256'],'rotation_modes':modes,'cameras':cameras,'return_scene':'ANIMATION_SHOWCASE','hud_root':hud.name,'playback_sync':'FRAME_DROP','preview_arc_original_adapter':True,'takeoff_time_s':m.START,'contact_time_s':m.START+m.FLIGHT,'preview_apex_m':m.HEIGHT,'preview_flight_s':m.FLIGHT}
s[ui.REVIEW_TAG]=review['id'];s[ui.REVIEW_ENTRY]=json.dumps(review);ui.validate_review_sequence(review)
data['animations'].extend(entries);data['review_sequences'].append(review);focus=data.get('library_focus',{});focus['entries']=[{'kind':'review_sequence','id':review['id']}]+[{'kind':'action','id':e['action']}for e in entries]+focus.get('entries',[]);data['library_focus']=focus
for path,digest in base['files'].items():assert sha(Path(path))==digest,'Concurrent library edit before write'
manifest.write_text(json.dumps(data,indent=2),encoding='utf8')
print('REFRESHING_EXISTING_REGISTRY',flush=True);faulthandler.dump_traceback_later(90,repeat=True)
home=bpy.data.scenes['ANIMATION_SHOWCASE'];ui.refresh(home,import_missing=False)
print('CHECKING_OLD_ACTION_SIGNATURES',len(base['actions']),flush=True)
for name,digest in base['actions'].items():assert ui.action_signature(bpy.data.actions[name])==digest,name
faulthandler.cancel_dump_traceback_later()
assert ui.rest_signature(native.data)==data['rig_sha256']
ui.open_review_sequence(bpy.context,review['id']);s.gaf_loop=True;s.frame_set(1)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(central))
(H/'installation.json').write_text(json.dumps({'old_actions_preserved':len(base['actions']),'total_actions':len(bpy.data.actions),'old_registry_preserved':base['registry_count'],'old_reviews_preserved':base['review_count'],'entries':entries,'review':review},indent=2),encoding='utf8')
for label,frame in [('apex',40),('landing',59)]:s.frame_set(frame);s.render.filepath=str(H/('context_'+label+'.png'));bpy.ops.render.render(write_still=True,scene=s.name)
print('JUMP_INSTALLED_PENDING',len(entries),flush=True)
