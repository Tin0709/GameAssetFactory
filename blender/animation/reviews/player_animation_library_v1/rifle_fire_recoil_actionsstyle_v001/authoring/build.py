"""Original single-shot rifle recoil on the immutable approved research Aim base."""
import bpy,json,sys,math,hashlib,argparse
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
p=argparse.ArgumentParser();p.add_argument('--repo');opt=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
S=Path(__file__).resolve().parent;O=S.parent;R=Path(opt.repo) if opt.repo else next(p for p in S.parents if (p/'AGENTS.md').exists());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
E=json.loads((S/'baseline_entry.json').read_text());assert E['status']=='approved';source=R/E['source'];assert hashlib.sha256(source.read_bytes()).hexdigest()==E['source_sha256'];bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;base=bpy.data.actions[E['action']];assert ui.action_signature(base)==E['action_sha256'];N='Rifle_Fire_Recoil_ActionsStyle_v001';assert N not in bpy.data.actions
old={a.name:ui.action_signature(a) for a in bpy.data.actions};r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=base.name;s.frame_set(85);bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones}
P={'amplitude_multiplier':1.5,'left_support_clearance_roll_deg':.6,'duration_s':1/6,'fps':30,'bake_hz':240,'approved_aim_reference_frame':85,'first_motion_s':1/240,'primary_peak_after_motion_s':.025,'primary_recovery_end_s':.0958333333333,'countersettle_window_s':[.0583333333333,.1125],'countersettle_gain':.055,'arm_kick_deg':1.1,'right_shoulder_back_m':.006,'right_hand_drop_m':.0015,'spine_back_deg':.15,'chest_back_deg':.45,'body_delay_s':2/240,'head_counterpitch_deg':.22,'head_delay_s':3/240,'left_support_delay_s':2/240,'left_support_secondary_up_m':.0007,'left_support_secondary_foreaft_m':.0005,'repeat_demo_hz':6.,'origin':'All recoil envelopes, amplitudes and coordination authored originally; source crossbow used for principles only.'}
C=B['UpperArm.R'].inverted()@B['WeaponCarrier'];FL=B['UpperArm.L'].inverted()@B['ForeArm.L'];FR=B['UpperArm.R'].inverted()@B['ForeArm.R'];palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));palm_arm=FL@palm;palm_right=FR@palm;anchor=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm)
forward=B['WeaponCarrier'].to_3x3().col[1].normalized();up=Vector((0,0,1));axis=forward.cross(up).normalized()
def smooth(u):u=max(0.,min(1.,u));return u*u*u*(10+u*(-15+6*u))
def env(t,delay=0):
 t-=P['first_motion_s']+delay
 if t<=0:return 0.
 peak=P['primary_peak_after_motion_s'];end=P['primary_recovery_end_s'];value=smooth(t/peak) if t<peak else 1-smooth((t-peak)/(end-peak))
 a,b=P['countersettle_window_s']
 if a<t<b:value-=P['countersettle_gain']*math.sin(math.pi*(t-a)/(b-a))**2
 return value*P['amplitude_multiplier']

def turn(M,axis,angle):
 Q=Quaternion(axis,math.radians(angle)).to_matrix().to_4x4();q=Q@M;q.translation=M.translation;return q

def target(t):
 e=env(t);body=env(t,P['body_delay_s']);head=env(t,P['head_delay_s']);support=env(t,P['left_support_delay_s'])
 if max(abs(x) for x in [e,body,head,support])<1e-10:return {n:m.copy() for n,m in B.items()}
 M={n:m.copy() for n,m in B.items()};M['Spine']=turn(B['Spine'],axis,P['spine_back_deg']*body);ds=M['Spine']@B['Spine'].inverted();M['Chest']=turn(ds@B['Chest'],ds.to_3x3()@axis,P['chest_back_deg']*body);dc=M['Chest']@B['Chest'].inverted();ax=dc.to_3x3()@axis;fwd=dc.to_3x3()@forward
 M['Neck']=dc@B['Neck'];M['Head']=dc@B['Head']@Matrix.Rotation(math.radians(P['head_counterpitch_deg']*head),4,'X')
 carry=dc@B['UpperArm.R'];pivot=carry@palm_right;Q=Quaternion(ax,math.radians(P['arm_kick_deg']*e)).to_matrix().to_4x4();M['UpperArm.R']=Q@carry;M['UpperArm.R'].translation=pivot+Q.to_3x3()@(carry.translation-pivot)-fwd*P['right_shoulder_back_m']*e-(dc.to_3x3()@up)*P['right_hand_drop_m']*e
 M['ForeArm.R']=M['UpperArm.R']@FR;M['WeaponCarrier']=M['UpperArm.R']@C
 desired=M['WeaponCarrier']@anchor+(dc.to_3x3()@up)*P['left_support_secondary_up_m']*(support-e)+fwd*P['left_support_secondary_foreaft_m']*(support-e)
 L=dc@B['UpperArm.L'];vec=L.to_3x3()@palm_arm;aim=desired-L.translation;rot=vec.normalized().rotation_difference(aim.normalized());basis=rot.to_matrix()@L.to_3x3();basis=Quaternion((basis@palm_arm).normalized(),math.radians(P['left_support_clearance_roll_deg']*e)).to_matrix()@basis;M['UpperArm.L']=basis.to_4x4();M['UpperArm.L'].translation=desired-basis@palm_arm;M['ForeArm.L']=M['UpperArm.L']@FL
 return M

times=[i/240 for i in range(41)];data={b.name:[] for b in r.pose.bones};maxscale=0.
for t in times:
 M=target(t)
 for b in r.data.bones:
  opts={'parent_matrix':M[b.parent.name],'parent_matrix_local':b.parent.matrix_local} if b.parent else {}
  basis=b.convert_local_to_pose(M[b.name],b.matrix_local,invert=True,**opts);loc,q,scale=basis.decompose();maxscale=max(maxscale,max(abs(v-1) for v in scale));data[b.name].append((loc,q,scale))
assert maxscale<2e-6
act=bpy.data.actions.new(N);slot=act.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=act.layers.new('Original rifle impulse and controlled recovery').strips.new(type='KEYFRAME').channelbag(slot,ensure=True);act.use_fake_user=True
for b in r.pose.bones:
 rows=data[b.name];qs=[x[1].copy() for x in rows]
 for i in range(1,len(qs)):
  if qs[i].dot(qs[i-1])<0:qs[i].negate()
 rots=qs if b.rotation_mode=='QUATERNION' else [q.to_euler(b.rotation_mode) for q in qs]
 for prop,arr in [('location',[x[0] for x in rows]),('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler',rots),('scale',[Vector((1,1,1)) for x in rows])]:
  for j in range(len(arr[0])):
   c=bag.fcurves.new(b.path_from_id(prop),index=j);c.keyframe_points.add(len(times));c.keyframe_points.foreach_set('co',[v for t,row in zip(times,arr) for v in (1+t*30,row[j])]);
   for k in c.keyframe_points:k.interpolation='LINEAR'
   c.update()
act['research_only']=True;act['production_eligible']=False;act['original_recoil']=True;act['contains_approved_source_derived_aim_base']=True;act['description']='Single original rifle recoil. Absolute return to the approved Aim F85. No accumulated transforms.'
r.animation_data.action=act;r.animation_data.action_slot=slot;s['gaf_library_last_action']=N;s.frame_start=1;s.frame_end=5;s.render.fps=30;s.render.fps_base=1.;s.frame_set(2);ui.show_preview_prop(s,E)
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in old.items());out=O/'rifle_fire_recoil_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e=dict(E)
for k in ['approval_date','rig_adaptations','visual_base_action_sha256','source_profile','source_duration_s']:e.pop(k,None)
e.update(action=N,source='blender/animation/reviews/player_animation_library_v1/rifle_fire_recoil_actionsstyle_v001/'+out.name,source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),action_frame_range=[1.,6.],start=1,end=5,fps=30,fps_base=1.,status='pending',approval_note='New original rifle recoil on the approved research Aim base; Pending artistic review. No Godot integration.',seamless_loop=True,source_derived_reconstruction=False,original_custom_animation=True,contains_source_derived_aim_base=True,bake_hz=240,duration_s=1/6,endpoint_sample_frame=6,visual_base=E['action'],visual_base_frame=85,visual_base_source_sha256=E['source_sha256'],source_animations=['animation.oreville_ans.pomlkz'],source_reference_only=True,original_recoil_parameters=P,review_repeat_hz=6.)
ui.validate_action(act,e,r);(O/'entry.json').write_text(json.dumps(e,indent=2));(S/'parameters.json').write_text(json.dumps(P,indent=2));(S/'source_actions_before.json').write_text(json.dumps(old,indent=2));(O/'build_validation.json').write_text(json.dumps({'passed':True,'new_action':N,'original_recoil':True,'base_frame':85,'preserved_embedded_actions':len(old),'samples':len(times),'maximum_scale_error':maxscale,'action_sha256':e['action_sha256'],'source_sha256':e['source_sha256']},indent=2));print('BUILT',N,e['action_sha256'],flush=True)
