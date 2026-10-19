import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
import argparse
p=argparse.ArgumentParser();p.add_argument('--cache',required=True);opt=p.parse_args(sys.argv[sys.argv.index('--')+1:])
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());S=Path(opt.cache).resolve();O=R/'blender/animation/reviews/player_animation_library_v1/crossbow_aim_actionsstuff_source_v001';O.mkdir(exist_ok=True)
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
sys.path.insert(0,str(R/'blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001'));from idle_retarget import JumpRetarget
N='Crossbow_Aim_ActionsStuff_Source_Test_v001';rig=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene
assert N not in bpy.data.actions
mf=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());e0=next(e for e in mf['animations'] if e['action']=='Rifle_Ready_Idle_ActionsStyle_v004');a0=bpy.data.actions[e0['action']];assert ui.action_signature(a0)==e0['action_sha256']
rig.animation_data.action=a0;rig.animation_data.action_slot=a0.slots[0];s.frame_set(1);bpy.context.view_layer.update();approved={b.name:b.matrix.copy() for b in rig.pose.bones}
# The only weapon adapter: hold the original rifle grip position in the rigid
# right-hand frame. Align rifle axis to source item frame; never solve either arm.
mount=approved['UpperArm.R'].inverted()@approved['WeaponCarrier'];mount_pos=mount.translation.copy()
rig.animation_data.action=None
for n,values in json.loads(bpy.data.texts[ui.BASELINE].as_string()).items():
 for prop,v in values.items():setattr(rig.pose.bones[n],prop,v)
bpy.context.view_layer.update();mapper=JumpRetarget(rig);rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
# Native upper-arm +Y is the straight limb axis. Rifle barrel is also +Y,
# with +Z top; source item angles are applied after this fixed attachment basis.
mount=Matrix.Identity(4);mount.translation=mount_pos
rows=json.loads((S/'samples.json').read_text());before={a.name:ui.action_signature(a) for a in bpy.data.actions};values=[];targets=[];maxscale=0.;maxshear=0.;forearm=0.
for sample in rows:
 ch=sample['channels'];M=mapper.desired(ch,entity_head=True)
 Wrest=mapper.base['UpperArm.R']@mount
 item=mapper.transform(ch['rightitem'],Wrest.translation)
 # Source item axes live in the unanimated arm parent frame, not native bone axes.
 # Rotate at the hand attachment and then inherit full source right-arm hierarchy.
 M['WeaponCarrier']=M['UpperArm.R']@mapper.base['UpperArm.R'].inverted()@item@Wrest
 row={}
 for b in rig.data.bones:
  kw={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':rest[b.parent.name]}
  L=b.convert_local_to_pose(M[b.name],rest[b.name],invert=True,**kw);pos,q,scale=L.decompose();maxscale=max(maxscale,max(abs(x-1) for x in scale));rebuilt=Matrix.LocRotScale(pos,q,scale);maxshear=max(maxshear,max(abs(L[i][j]-rebuilt[i][j]) for i in range(4) for j in range(4)))
  if b.name.startswith('ForeArm.'):forearm=max(forearm,max(abs(L[i][j]-float(i==j)) for i in range(4) for j in range(4)))
  row[b.name]=(pos.copy(),q.copy(),Vector((1,1,1)))
 values.append(row);targets.append(M)
assert max(maxscale,maxshear,forearm)<1e-5
act=bpy.data.actions.new(N);slot=act.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=act.layers.new('Literal charged crossbow graph | no rifle pose fit').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
for b in rig.pose.bones:
 prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler';data={'location':[],prop:[],'scale':[]};previous=None
 for row in values:
  p,q,sc=row[b.name];q=q.copy()
  if prop=='rotation_quaternion':
   if previous is not None and q.dot(previous)<0:q.negate()
   rotation=q
  else:rotation=q.to_euler(b.rotation_mode,previous) if previous is not None else q.to_euler(b.rotation_mode)
  previous=rotation.copy()
  for name,v in [('location',p),(prop,rotation),('scale',sc)]:data[name].append(list(v))
 for prop,array in data.items():
  for axis in range(len(array[0])):
   fc=bag.fcurves.new(b.path_from_id(prop),index=axis);fc.keyframe_points.add(len(rows));fc.keyframe_points.foreach_set('co',[x for sample,v in zip(rows,array) for x in [1+sample['t']*30,v[axis]]])
   for k in fc.keyframe_points:k.interpolation='LINEAR'
   fc.modifiers.new('CYCLES');fc.update()
act.use_fake_user=True;act['research_only']=True;act['production_eligible']=False;act['source_pack_sha256']=e0['source_pack_sha256'];act['pose_truth']='actual charged crossbow channels; zero arm/torso/head fit correction';act['weapon_adapter']='original right-hand grip position; barrel aligned with straight-arm item frame'
rig.animation_data.action=act;rig.animation_data.action_slot=slot;s['gaf_library_last_action']=N;s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});s.camera=bpy.data.objects['Showcase_THREE_QUARTER']
# Validate actual evaluated bones against independently requested target matrices.
error=0.;seam=None
for i in range(0,len(rows),4):
 f=1+rows[i]['t']*30;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update()
 error=max(error,max(abs(b.matrix[x][y]-targets[i][b.name][x][y]) for b in rig.pose.bones for x in range(4) for y in range(4)))
assert error<1e-5,error
s.frame_set(1);bpy.context.view_layer.update();first={b.name:b.matrix.copy() for b in rig.pose.bones};s.frame_set(109);bpy.context.view_layer.update();seam=max(abs(b.matrix[x][y]-first[b.name][x][y]) for b in rig.pose.bones for x in range(4) for y in range(4));assert seam<1e-5
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
s.frame_set(1);out=O/'crossbow_aim_actionsstuff_source_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e={k:v for k,v in e0.items() if k in ['source_rig','source_mesh','source_armature','slot_identifier','rotation_modes','preview_prop','preview_prop_source','preview_prop_source_sha256','source_pack_sha256']};e.update(action=N,source=out.relative_to(R).as_posix(),source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),action_frame_range=list(act.frame_range),start=1,end=108,fps=30,fps_base=1.,status='pending',approval_note='Literal source charged-crossbow aim pose requested2026-10-19. No custom rifle arm/pose fitting. Pending Blender review; research-only.',seamless_loop=True,research_only=True,production_eligible=False,source_derived_reconstruction=True,original_custom_animation=False,bake_hz=240,source_duration_s=3.6,endpoint_sample_frame=109,source_animations=['animation.oreville_ans.rrvlnm','animation.oreville_ans.dubgwy','animation.oreville_ans.jawwtn','animation.oreville_ans.asxvzc'],source_controllers=['controller.animation.oreville_ans.njvelc','controller.animation.oreville_ans.knoyhk'],source_profile='ordinary player0, already charged mainhand crossbow, no shield, grounded, neutral look; 0.6s charged entry warmup')
ui.validate_action(act,e,rig);(S/'entry.json').write_text(json.dumps(e,indent=2));(O/'entry.json').write_text(json.dumps(e,indent=2));report={'passed':True,'full_source_samples':len(rows),'baked_pose_matrix_error':error,'basis_scale_error':maxscale,'basis_shear_error':maxshear,'straight_forearm_identity_error':forearm,'loop_pose_error':seam,'rig_unit_m_per_source_unit':mapper.unit,'arm_body_head_fit_corrections':0,'weapon_attachment_position_in_right_arm':list(mount_pos),'source_arm_angles':{n:rows[0]['channels'][n]['rotation'] for n in ['rightarm','leftarm','body']},'source_item_channels':rows[0]['channels']['rightitem'],'source_rest_pivots':{n:list(b.matrix_local.translation) for n,b in rig.data.bones.items()},'source_actions_preserved':len(before),'action_sha256':e['action_sha256']};(S/'build_validation.json').write_text(json.dumps(report,indent=2));print('LITERAL_SOURCE_AIM_BUILT',json.dumps(report),flush=True)
# Fast review still before spending time on movies; presentation-only camera settings.
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
for view in ['FRONT','THREE_QUARTER','SIDE']:
 cam=bpy.data.objects['Showcase_'+view];cam.data=cam.data.copy();cam.data.ortho_scale*=1.18;s.camera=cam;s.render.filepath=str(S/('pose_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True)
