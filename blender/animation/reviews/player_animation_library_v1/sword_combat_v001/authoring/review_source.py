"""Reopen native source, validate rigidity/grip/support, render Pending review."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());OUT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
D=json.loads((OUT/'design.json').read_text());scene=bpy.data.scenes['SWORD_COMBAT_ORIGINAL_V001_REVIEW'];bpy.context.window.scene=scene;rig=bpy.data.objects[D['source_rig']];mesh=bpy.data.objects[D['source_mesh']];sword=bpy.data.objects['Sword_Sand_Block_V1']
mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'validate'
def frame(t):
 f=1+t*30;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def bind(e):
 a=bpy.data.actions[e['action']];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];return a
def validate():
 groups={g.index:g.name for g in mesh.vertex_groups}
 ids={side:[v.index for v in mesh.data.vertices if any(groups[g.group] in {'UpperArm.'+side,'ForeArm.'+side} and g.weight>.999 for g in v.groups)] for side in ['L','R']}
 headids=[v.index for v in mesh.data.vertices if any(groups[g.group]=='Head' and g.weight>.999 for g in v.groups)]
 hlo=Vector(tuple(min(mesh.data.vertices[i].co[a] for i in headids) for a in range(3)));hhi=Vector(tuple(max(mesh.data.vertices[i].co[a] for i in headids) for a in range(3)))
 blade=bpy.data.objects['Sword_Blade'];reports={};C=None
 for kind,e in D['clips'].items():
  a=bind(e);assert ui.action_signature(a)==e['action_sha256'];ui.validate_action(a,e,rig)
  maxrig=0.;maxscale=0.;maxhelper=0.;maxgrip=0.;maxsocket=0.;minfloor=99.;minblade=99.;maxstep=0.;prev={};headhits=[];rootx=[];n=0
  times=sorted({round(min(j/hz,e['duration']),10) for hz in [30,60,240] for j in range(math.ceil(e['duration']*hz)+1)})
  for t in times:
   frame(t);deps=bpy.context.evaluated_depsgraph_get();ev=mesh.evaluated_get(deps);geo=ev.to_mesh()
   for side,vids in ids.items():
    b=rig.pose.bones['UpperArm.'+side];m=b.matrix@b.bone.matrix_local.inverted()
    for i in vids:maxrig=max(maxrig,(geo.vertices[i].co-m@mesh.data.vertices[i].co).length)
   minfloor=min(minfloor,min(v.co.z for v in geo.vertices))
   for b in rig.pose.bones:
    maxscale=max(maxscale,max(abs(v-1) for v in b.scale));q=b.matrix.to_quaternion()
    if b.name in prev:maxstep=max(maxstep,prev[b.name].rotation_difference(q).angle)
    prev[b.name]=q
   for name in ['ForeArm.L','ForeArm.R','Neck']:
    m=rig.pose.bones[name].matrix_basis;maxhelper=max(maxhelper,max(abs(m[i][j]-(1 if i==j else 0)) for i in range(4) for j in range(4)))
   rel=rig.pose.bones['UpperArm.R'].matrix.inverted()@rig.pose.bones['WeaponCarrier'].matrix
   if C is None:C=rel.copy()
   maxgrip=max(maxgrip,max(abs(C[i][j]-rel[i][j]) for i in range(4) for j in range(4)))
   for side in ['L','R']:
    b=rig.pose.bones['Leg.'+side];h=rig.pose.bones['Hips'];socket=h.matrix@(h.bone.matrix_local.inverted()@b.bone.head_local);maxsocket=max(maxsocket,(b.head-socket).length)
   hm=rig.pose.bones['Head'].matrix@rig.data.bones['Head'].matrix_local.inverted();hinv=hm.inverted()
   for v in blade.data.vertices:
    point=blade.matrix_world@v.co;minblade=min(minblade,point.z);p=hinv@point
    if all(hlo[axis]+.002<p[axis]<hhi[axis]-.002 for axis in range(3)):
     headhits.append(t);break
   rootx.append(float(rig.pose.bones['Root'].rotation_euler.x));ev.to_mesh_clear();n+=1
  frame(0);first={b.name:b.matrix.copy() for b in rig.pose.bones};frame(e['duration']);endpoint=max(abs(b.matrix[i][j]-first[b.name][i][j]) for b in rig.pose.bones for i in range(4) for j in range(4))
  checks={'rigid_arms':maxrig<2e-5,'unit_scales':maxscale<1e-6,'identity_helpers':maxhelper<1e-6,'fixed_grip':maxgrip<2e-5,'connected_legs':maxsocket<.075,'no_body_floor_penetration':minfloor>-.0015,'blade_clears_head':not headhits,'loop_seam':not e['loop'] or endpoint<2e-5}
  if kind=='Roll':checks['unwrapped_complete_roll']=rootx[0]==0 and abs(rootx[-1]-2*math.pi)<1e-5 and all(b>=a-1e-5 for a,b in zip(rootx,rootx[1:]));checks['ground_support']=minfloor>=-.0015
  reports[kind]={'passed':all(checks.values()),'samples':n,'duration':e['duration'],'checks':checks,'max_arm_rigidity_error_m':maxrig,'max_scale_error':maxscale,'max_helper_identity_matrix_error':maxhelper,'max_grip_matrix_error':maxgrip,'max_leg_socket_distance_m':maxsocket,'minimum_body_floor_z_m':minfloor,'minimum_blade_z_m':minblade,'blade_head_intersections':headhits[:20],'endpoint_matrix_difference':endpoint,'max_pose_orientation_step_rad':maxstep,'root_x_range_rad':[min(rootx),max(rootx)]}
  print('SWORD_NATIVE_CHECK',kind,json.dumps(reports[kind]),flush=True)
 report={'passed':all(v['passed'] for v in reports.values()),'fps_checks':[30,60,240],'rig_signature':ui.rest_signature(rig.data),'clips':reports,'source_combo_unchanged':hashlib.sha256((R/D['original_combo_source']).read_bytes()).hexdigest()==D['original_combo_source_sha256']}
 (OUT/'geometry_validation.json').write_text(json.dumps(report,indent=2)+'\n');assert report['passed'],'Inspect geometry_validation.json'
def render():
 folder=OUT/'review';folder.mkdir(exist_ok=True);scene.render.resolution_x=scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=False
 frames={'Ready':0,'Attack1':.30,'Attack2':.20,'Attack3':.30,'Guard':0,'Parry':.065,'Roll':.25,'Hurt':.055}
 for view in ['THREE_QUARTER','FRONT','SIDE']:
  scene.camera=bpy.data.objects['SC_'+view]
  for kind,t in frames.items():
   bind(D['clips'][kind]);frame(t);scene.render.image_settings.file_format='PNG';scene.render.filepath=str(folder/(kind.lower()+'_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True,scene=scene.name)
 for t in [.12,.39,.56,.72]:
  bind(D['clips']['Roll']);frame(t);scene.camera=bpy.data.objects['SC_SIDE'];scene.render.filepath=str(folder/('roll_side_'+str(int(t*100))+'.png'));bpy.ops.render.render(write_still=True,scene=scene.name)
if mode=='validate':validate()
elif mode=='render':render()
