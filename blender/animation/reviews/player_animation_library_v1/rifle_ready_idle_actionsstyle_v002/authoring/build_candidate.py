import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());S=Path(__file__).resolve().parent
sys.path.insert(0,str(S));from motion_design import motion,HEAD,TORSO,WEIGHT,PERIOD
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
O=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v002';O.mkdir(parents=True,exist_ok=True)
NAME='Rifle_Ready_Idle_ActionsStyle_v002';source=Path(bpy.data.filepath)
registered=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())
if any(e['action']==NAME and e['status']=='approved' for e in registered['animations']):raise RuntimeError('Preserve approved Action; no rebuild allowed')
if (O/'rifle_ready_idle_actionsstyle_v002.blend').exists() and '--rebuild-pending' not in sys.argv:raise RuntimeError('Existing Pending source preserved; explicit --rebuild-pending required')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='22017e77d5a722d087c46bd839e38fbec5a30ac5a56bb4b326e86cbbbbee3fde'
rig=bpy.data.objects['Showcase_Player_Rig'];scene=bpy.context.scene
base=bpy.data.actions['Rifle_Ready_V2_v16_Test'];assert ui.action_signature(base)=='e12357dab1a854a4642f293e8049747f7e17b426ff69f1a4c331327b47e91743'
old={a.name:ui.action_signature(a) for a in bpy.data.actions}
rig.animation_data.action=base;rig.animation_data.action_slot=base.slots[0];scene.frame_set(1);bpy.context.view_layer.update()
B={b.name:b.matrix.copy() for b in rig.pose.bones};rest={b.name:b.bone.matrix_local.copy() for b in rig.pose.bones}
assert NAME not in bpy.data.actions
rig.animation_data.action=None
new=bpy.data.actions.new(NAME);new.use_fake_user=True;rig.animation_data.action=new
quats={};eulers={}
def pivot(p,rot):return Matrix.Translation(p)@rot@Matrix.Translation(-p)
def rot(angle,axis):return Matrix.Rotation(math.radians(angle),4,axis)
def targets(t):
 m=motion(t);w=Vector((m['weight'],.001*m['breathe'],.010*m['breathe']))
 cp=m['body_pitch'];c=B['Chest'].translation
 D=Matrix.Translation(w+Vector((0,0,.004*m['breathe'])))@pivot(c,rot(m['torso'],'Z')@rot(cp,'X')@rot(m['body_roll'],'Y'))
 hold=Matrix.Translation(w+Vector((0,-.008*m['drop']/.064,.004*m['breathe']-m['drop'])))@pivot(c,rot(m['hold'],'Z')@rot(m['hold_pitch'],'X'))
 M={n:x.copy() for n,x in B.items()}
 M['Hips']=Matrix.Translation(w)@B['Hips']
 M['Spine']=Matrix.Translation(w+Vector((0,0,.0015*m['breathe'])))@pivot(B['Spine'].translation,rot(.35*m['torso'],'Z'))@B['Spine']
 M['Chest']=D@B['Chest'];M['Neck']=Matrix.Translation((0,0,m['head_lift']))@D@B['Neck']
 M['Head']=Matrix.Translation((0,0,m['head_lift']))@D@pivot(B['Head'].translation,rot(m['head']-(m['torso']-11.),'Z')@rot(m['pitch'],'X')@rot(m['roll'],'Y'))@B['Head']
 for n in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']:M[n]=hold@B[n]
 # Both rigid legs keep their approved world stance/sole exactly. The tiny
 # pelvis transfer remains inside the original solid-block joint overlap.
 for n in ['Leg.L','Leg.R']:M[n]=B[n].copy()
 return M
for half in range(481):
 f=1+half*.5;t=(f-1)/30;scene.frame_set(int(f),subframe=f-int(f));M=targets(t)
 for b in rig.pose.bones:
  parent=b.parent
  basis=rest[b.name].inverted()@(rest[parent.name]@M[parent.name].inverted() if parent else Matrix.Identity(4))@M[b.name]
  p,q,scale=basis.decompose();b.location=p;b.scale=(1,1,1)
  if b.rotation_mode=='QUATERNION':
   if b.name in quats and q.dot(quats[b.name])<0:q.negate()
   b.rotation_quaternion=q;quats[b.name]=q.copy();prop='rotation_quaternion'
  else:
   e=basis.to_euler(b.rotation_mode,eulers.get(b.name));b.rotation_euler=e;eulers[b.name]=e.copy();prop='rotation_euler'
  b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert(prop,frame=f,group=b.name);b.keyframe_insert('scale',frame=f,group=b.name)
 for name in ['ForeArm.L','ForeArm.R']:
  assert abs(rig.pose.bones[name].matrix_basis.to_quaternion().angle)<.0001
for c in ui.curves(new):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 c.modifiers.new('CYCLES')
scene.frame_start=1;scene.frame_end=240;scene.render.fps=30;scene.render.fps_base=1.;scene.frame_set(1)
for e in bpy.data.actions:
 if e.name in old:assert ui.action_signature(e)==old[e.name]
scene['original_authorship']='Crossbow-informed original rifle idle v002. Third-person njvelc/ltqtzr/dubgwy/rrvlnm reference. Constrained static body blade and braced holding; independently authored8s scan and1/4s support rhythm. See REFERENCE.md.'
scene.camera=bpy.data.objects['Showcase_THREE_QUARTER'];scene.render.engine='CYCLES';scene.cycles.samples=24
ui.show_preview_prop(scene,{'preview_prop':'rifle_stylized_v2'})
source_new=O/'rifle_ready_idle_actionsstyle_v002.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source_new),check_existing=False)
entry={'action':NAME,'source':source_new.relative_to(R).as_posix(),'source_sha256':hashlib.sha256(source_new.read_bytes()).hexdigest(),'source_rig':rig.name,'source_mesh':'Showcase_Player_Mesh','source_armature':rig.data.name,'slot_identifier':new.slots[0].identifier,'action_sha256':ui.action_signature(new),'action_frame_range':list(new.frame_range),'start':1,'end':240,'fps':30,'fps_base':1.,'status':'pending','approval_note':'Crossbow-informed custom rifle-ready v002, Pending comparison against v001. Exact relative two-hand hold and actual Rifle Stylized V2 preserved. Independently authored temporal curves; constrained pose adapter described in REFERENCE.md. Blender-only; no Godot before explicit approval.','seamless_loop':True,'rotation_modes':{b.name:b.rotation_mode for b in rig.pose.bones},'preview_prop':'rifle_stylized_v2','preview_prop_source':'blender/weapons/rifle_stylized_v2/Rifle_Stylized_V2.blend','preview_prop_source_sha256':'0d8c2d0fb05e8be82d5c2a3485eb3cd1a40acdc70c1e656ed2f4322e17bad03f','original_custom_animation':True,'source_derived_reconstruction':False,'production_eligible':False,'authorship':'Actions & Stuff third-person crossbow primary pose/layering reference; independently authored scan/support curves, approved rifle grip retained. Not a literal reconstruction; arm-angle limitations explicitly documented.'}
ui.validate_action(new,entry,rig);(S/'candidate_entry.json').write_text(json.dumps(entry,indent=2));(O/'entry.json').write_text(json.dumps(entry,indent=2))
(O/'design.json').write_text(json.dumps({'duration':8,'head_keys':HEAD,'torso_keys':TORSO,'assembly_clearance':'64mm attention clearance,5.5mm Neck release; original grip preserved; whole upper body and holding frame share11deg ready blade.','pelvis_weight_keys':WEIGHT,'breath':'Original1s holding rebound,4s weight drift informed by crossbow4:1 harmonic structure.10mm pelvis/4mm chest; identical arm/weapon frame suppresses free swing.','common_rigid_holding_assembly':True,'authored_independently':True,'base_entry_sha256':entry['action_sha256'],'source_keyframes_imported':False},indent=2))
print('CANDIDATE_BUILT',entry['action_sha256'],flush=True)
