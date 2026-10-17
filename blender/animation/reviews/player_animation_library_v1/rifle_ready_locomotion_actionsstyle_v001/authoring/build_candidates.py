"""Build two NEW research candidates from crossbow graph, approved v004 calibration.
Never change the approved base; one common study file, central Showcase registration later.
"""
import bpy,sys,math,json,hashlib,time
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());A=Path(__file__).resolve().parent;O=A.parent
sys.path.insert(0,str(A));sys.path.insert(0,str(R/'blender/animation/showcase'))
import gaf_animation_library as ui
from locomotion_source import Sampler,PROFILE,HZ,extract,IdleRuntime,query
sys.path.insert(0,str(R/'blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001'))
from idle_retarget import JumpRetarget
sys.path.insert(0,str(R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring'))
from support_motion import sample as breath
S=Path('/Users/tin/Documents/ChatGPT/New project/experiments/rifle_ready_locomotion_actionsstyle_v001')
BASE='Rifle_Ready_Idle_ActionsStyle_v004';base=bpy.data.actions[BASE];assert ui.action_signature(base)=='88b1ce9fe830f3377a58b8bf1cf04f1f602372f287b559aae8ee28e576d8409b'
before={a.name:ui.action_signature(a) for a in bpy.data.actions};r=bpy.data.objects[ui.RIG];m=bpy.data.objects["Showcase_Player_Mesh"];s=bpy.context.scene
r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=BASE;s.frame_set(1);bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};rest={b.name:b.matrix_local.copy() for b in r.data.bones}
palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));anchor=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm)
r.animation_data.action=None
for n,values in json.loads(bpy.data.texts[ui.BASELINE].as_string()).items():
 for prop,v in values.items():setattr(r.pose.bones[n],prop,v)
bpy.context.view_layer.update();mapper=JumpRetarget(r)
payload=extract('/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack',S/'cache')
idle=IdleRuntime(payload,initial_life=13.4,seed=139,modified_distance_moved=1,attack_free_age=12)
for i in range(HZ):ir=idle.step(1/HZ,query())
raw0=mapper.desired(ir['channels']);leftrel=B['UpperArm.L'].inverted()@B['ForeArm.L']
normal=Vector((-.645238,.756959,-.102245));tangent=Vector((.760946,.648799,0))
# Inherit the exact authored v004 support breathing directions (from its build provenance).
bp=json.loads((R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/build_validation.json').read_text());normal=Vector(bp['support_normal_carrier_local']);tangent=Vector(bp['support_tangent_carrier_local']);breath0=breath(0)
footverts={n:[v.co.copy() for v in m.data.vertices if any(g.group==m.vertex_groups[n].index and g.weight>.99 for g in v.groups)] for n in ['Leg.L','Leg.R']}
entries=[];reports=[];out=O/'rifle_ready_locomotion_actionsstyle_v001.blend'
for kind in ['Walk','Run']:
 start=time.time();sampler=Sampler(payload,kind);times=sampler.times();profile=PROFILE[kind];N='Rifle_Ready_'+kind+'_ActionsStyle_v001';assert N not in bpy.data.actions
 values={n:{'location':[],'rotation_quaternion' if r.pose.bones[n].rotation_mode=='QUATERNION' else 'rotation_euler':[],'scale':[]} for n in rest};previous={};metrics={'sole_lift_max_m':0.,'head_anchor_error_m':0.,'support_delta_max_m':0.,'shear_error':0.,'forearm_identity_error':0.}
 for j,t in enumerate(times):
  ch=sampler.value(t);M=mapper.desired(ch)
  # Constant static calibration from source crossbow to the APPROVED current rifle setup.
  for side in ['R','L']:
   D=M['UpperArm.'+side]@raw0['UpperArm.'+side].inverted()
   for n in ['UpperArm.'+side,'ForeArm.'+side]:M[n]=D@B[n]
   if side=='R':M['WeaponCarrier']=D@B['WeaponCarrier']
  # Preserve controlled right grip; left stays a straight support with inherited tiny pressure life.
  b=breath(t);delta=normal*(b['pressure_release_m']-breath0['pressure_release_m'])+tangent*(b['along_rifle_m']-breath0['along_rifle_m']);metrics['support_delta_max_m']=max(metrics['support_delta_max_m'],delta.length)
  P=M['WeaponCarrier']@(anchor+delta);socket=(M['Chest']@rest['Chest'].inverted()@rest['UpperArm.L']).translation-M['Chest'].to_3x3().col[0].normalized()*.006
  U=M['UpperArm.L'];F=M['ForeArm.L'];oldP=F@palm;swing=(U.translation-oldP).rotation_difference(socket-P);rotation=swing.to_matrix()@U.to_3x3();U=rotation.to_4x4();U.translation=P-rotation@(leftrel@palm);M['UpperArm.L']=U;M['ForeArm.L']=U@leftrel
  # No floating head: native head pivot remains exactly at torso-top base.
  top=M['Chest']@rest['Chest'].inverted()@Vector((0,0,1.35));M['Head'].translation=top;M['Neck'].translation=top
  metrics['head_anchor_error_m']=max(metrics['head_anchor_error_m'],(M['Head'].translation-top).length)
  # Native square boot sole adapter only; source rotation/X/Y and scale retained.
  for n in footverts:
   z=min((M[n]@rest[n].inverted()@v).z for v in footverts[n]);lift=max(0.,.0004-z);M[n]=Matrix.Translation((0,0,lift))@M[n];metrics['sole_lift_max_m']=max(metrics['sole_lift_max_m'],lift)
  for bone in r.data.bones:
   n=bone.name;kw={} if not bone.parent else {'parent_matrix':M[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]};local=bone.convert_local_to_pose(M[n],rest[n],invert=True,**kw)
   if n.startswith('ForeArm.'):
    metrics['forearm_identity_error']=max(metrics['forearm_identity_error'],max(abs(local[i][k]-float(i==k)) for i in range(4) for k in range(4)));local=Matrix.Identity(4)
   pos,q,scale=local.decompose();rebuild=Matrix.LocRotScale(pos,q,scale);metrics['shear_error']=max(metrics['shear_error'],max(abs(local[i][k]-rebuild[i][k]) for i in range(4) for k in range(4)))
   prop='rotation_quaternion' if r.pose.bones[n].rotation_mode=='QUATERNION' else 'rotation_euler'
   if prop=='rotation_quaternion':
    if n in previous and q.dot(previous[n])<0:q.negate()
    rot=q;previous[n]=q.copy()
   else:rot=q.to_euler(r.pose.bones[n].rotation_mode,previous.get(n));previous[n]=rot.copy()
   values[n]['location'].append(list(pos));values[n][prop].append(list(rot));values[n]['scale'].append(list(scale))
  if j%4000==0:print(kind,'sample',j,'/',len(times),flush=True)
 act=bpy.data.actions.new(N);slot=act.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=act.layers.new('Crossbow source graph | approved v004 rifle calibration').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
 for n,data in values.items():
  for prop,rows in data.items():
   for axis in range(len(rows[0])):
    ys=[v[axis] for v in rows];ix=[0,len(times)-1] if max(ys)-min(ys)<2e-7 else range(len(times));fc=bag.fcurves.new(r.pose.bones[n].path_from_id(prop),index=axis);fc.keyframe_points.add(len(ix));fc.keyframe_points.foreach_set('co',[v for i in ix for v in [1+times[i]*30,ys[i]]])
    for k in fc.keyframe_points:k.interpolation='LINEAR'
    # Viewer loops timeline; scale keys are modifier-free per verified source policy.
    fc.update()
 act.use_fake_user=True;act['research_only']=True;act['production_eligible']=False;act['visual_base']=BASE
 e={'action':N,'source':out.relative_to(R).as_posix(),'source_rig':r.name,'source_mesh':m.name,'source_armature':r.data.name,'slot_identifier':slot.identifier,'action_sha256':ui.action_signature(act),'action_frame_range':list(act.frame_range),'start':1,'end':round(profile['duration']*30),'fps':30,'fps_base':1.,'status':'pending','approval_note':'Pending Blender review. Literal crossbow locomotion with approved v004 rifle calibration; research-only.','seamless_loop':True,'research_only':True,'production_eligible':False,'source_derived_reconstruction':True,'original_custom_animation':False,'source_animation':sampler.rt.channels.aliases[profile['clip']],'source_pack_sha256':'9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d','rotation_modes':{b.name:b.rotation_mode for b in r.pose.bones},'preview_prop':'rifle_stylized_v2','bake_hz':HZ,'refinement_base':BASE,'duration_s':profile['duration'],'core_period_s':1/profile['rate'],'phase_rate_cycles_s':profile['rate'],'virtual_source_speed_blocks_s':profile['speed'],'source_life_origin_s':sampler.row['life'],'source_phase_origin':sampler.row['phase'],'endpoint_sample_frame':1+round(profile['duration']*30),'in_place':True,'loop_note':'Natural recurrence of source gait and independent crossbow lifetime clocks. No short-cycle clock reset.'}
 if kind=='Run':e['research_scale_channels']={n:{'axis':1,'min':1.0,'max':1.070002} for n in ['Leg.L','Leg.R']}
 ui.validate_action(act,e,r);entries.append(e)
 loop=max(abs(values[n][p][0][i]-values[n][p][-1][i]) for n in values for p in values[n] for i in range(len(values[n][p][0])))
 parity=sampler.evidence();assert parity<1e-7;assert metrics['shear_error']<1e-5;assert metrics['forearm_identity_error']<1e-5
 reports.append({'action':N,'passed':loop<1e-5,'samples':len(times),'duration_s':profile['duration'],'core_period_s':1/profile['rate'],'steady_graph_parity_max_channel_error':parity,'local_loop_channel_error':loop,'metrics':metrics,'layers':[{'alias':l['alias'],'id':sampler.rt.channels.aliases[l['alias']],'weight':l['applied_weight']} for l in sampler.row['layers'] if l['applied_weight']>0],'seconds':time.time()-start})
 print('BUILT',json.dumps(reports[-1]),flush=True)
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
r.animation_data.action=bpy.data.actions[entries[0]['action']];r.animation_data.action_slot=r.animation_data.action.slots[0];s['gaf_library_last_action']=r.animation_data.action.name;s.frame_start=1;s.frame_end=entries[0]['end'];s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False);sha=hashlib.sha256(out.read_bytes()).hexdigest()
for e in entries:e['source_sha256']=sha
(O/'entries.json').write_text(json.dumps(entries,indent=2));(O/'source_build_validation.json').write_text(json.dumps({'passed':all(x['passed'] for x in reports),'approved_v004_action_unchanged':True,'reports':reports},indent=2))
