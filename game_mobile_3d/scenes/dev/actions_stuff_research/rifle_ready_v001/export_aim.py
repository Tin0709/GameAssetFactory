"""Read-only export of the approved Aim Action; full evaluated PRS and support point."""
import sys
sys.dont_write_bytecode=True
import bpy,json,hashlib,math,struct,argparse
from pathlib import Path
from mathutils import Matrix,Vector
args=argparse.ArgumentParser();args.add_argument('--stage',required=True);args.add_argument('--repo');args.add_argument('--manifest');opt=args.parse_args(sys.argv[sys.argv.index('--')+1:]);R=Path(opt.repo) if opt.repo else next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());S=Path(opt.stage);S.mkdir(parents=True,exist_ok=True)
D=Path(__file__).resolve().parent;sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
mf=json.loads((Path(opt.manifest) if opt.manifest else R/'blender/animation/showcase/animation_manifest.json').read_text());N={'Aim':'Crossbow_Aim_ActionsStuff_Refined_Test_v001'};entries={k:next(e for e in mf['animations'] if e['action']==n) for k,n in N.items()}
for e in entries.values():assert e['status']=='approved';assert hashlib.sha256((R/e['source']).read_bytes()).hexdigest()==e['source_sha256']
source=R/entries['Aim']['source'];sha=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False);rig=bpy.data.objects[ui.RIG];scene=bpy.context.scene
names=[b.name for b in rig.data.bones];aliases={'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'};A=Matrix.Rotation(-math.pi/2,4,'X');palm=Vector((0,rig.data.bones['ForeArm.L'].length*.78,0));rows=lambda M:[list(x) for x in M]
profile={'schema':1,'research_only':True,'production_eligible':False,'source_pack_sha256':entries['Aim']['source_pack_sha256'],'bones':[aliases.get(n,n) for n in names],'clips':{},'palm_forearm_local':list(palm),'forearm_left_rest':rows(rig.data.bones['UpperArm.L'].matrix_local.inverted()@rig.data.bones['ForeArm.L'].matrix_local),'shoulder_left_chest_local':list((rig.data.bones['Chest'].matrix_local.inverted()@rig.data.bones['UpperArm.L'].matrix_local).translation),'shoulder_outset_m':.004}
fixtures=[];grip_rel=None;max_grip=0.;static_body_rel=None
for kind,e in entries.items():
 # Each approved Action has its own pinned source; same-named older Actions may coexist elsewhere.
 bpy.ops.wm.open_mainfile(filepath=str(R/e['source']),load_ui=False);rig=bpy.data.objects[ui.RIG];scene=bpy.context.scene
 assert [b.name for b in rig.data.bones]==names
 act=bpy.data.actions[e['action']];assert ui.action_signature(act)==e['action_sha256'];rig.animation_data.action=act;rig.animation_data.action_slot=act.slots[0];scene['gaf_library_last_action']=act.name
 duration=e.get('duration_s',e.get('source_duration_s',10.8));times=sorted({round((float(k.co.x)-1)/30,10) for c in ui.curves(act) for k in c.keyframe_points}|{0.,duration});assert abs(times[-1]-duration)<1e-7
 previous={};samples=[];fixture_indices={0,len(times)-1}|{int((len(times)-1)*x) for x in [.013,.071,.149,.251,.373,.501,.641,.799,.941]}
 for i,t in enumerate(times):
  f=1+t*30;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in rig.pose.bones};C=M['UpperArm.R'].inverted()@M['WeaponCarrier']
  if grip_rel is None:grip_rel=C.copy();static_body_rel=M['WeaponCarrier'].inverted()@bpy.data.objects['Rifle_V2_Body'].matrix_world
  max_grip=max(max_grip,max(abs(C[a][b]-grip_rel[a][b]) for a in range(4) for b in range(4)))
  data=[t];poses={}
  for b in rig.data.bones:
   local=M[b.parent.name].inverted()@M[b.name] if b.parent else A@M[b.name];p,q,scale=local.decompose()
   if b.name in previous and q.dot(previous[b.name])<0:q.negate()
   previous[b.name]=q.copy();values=[*p,q.x,q.y,q.z,q.w,*scale];data+=values;poses[aliases.get(b.name,b.name)]=values
  support=M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm);data+=list(support);samples.append(data)
  if i in fixture_indices:fixtures.append({'kind':kind,'time':t,'poses':poses,'support':list(support),'weapon_body_world':rows(A@bpy.data.objects['Rifle_V2_Body'].matrix_world)})
  if i%6000==0:print(kind,'export',i,'/',len(times),flush=True)
 raw=S/(kind.lower()+'.bin')
 with raw.open('wb') as out:
  for data in samples:out.write(struct.pack('<'+'f'*len(data),*data))
 profile['clips'][kind]={'action':e['action'],'duration':duration,'samples':len(samples),'row_floats':len(samples[0]),'raw_file':raw.name,'source':e['source'],'source_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'phase_origin':float(e.get('source_phase_origin',0.))%1.,'phase_rate':float(e.get('phase_rate_cycles_s',0.)),'loop':True}
 print('EXPORTED',kind,len(samples),raw.stat().st_size,flush=True)
profile['carrier_in_right_arm_first_sample']=rows(grip_rel)
profile['note']='Runtime samples the evaluated Aim arm-relative attachment at every time; no static mount assumption.'
# Standalone GLB is the existing exact preferred Rifle V2 export. Its vertices
# use Y-up; the approved attachment is in the native bone-local Blender frame.
weapon=R/'blender/weapons/rifle_stylized_v2/Rifle_Stylized_V2.blend';wsha=hashlib.sha256(weapon.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(weapon),load_ui=False);body=bpy.data.objects['Rifle_V2_Body'];mount=static_body_rel@body.matrix_world.inverted()@A.inverted();profile['weapon_mount']=rows(mount);profile['weapon_source_sha256']=wsha;profile['rifle_asset']='res://assets/weapons/rifle_stylized_v2_test/Rifle_Stylized_V2.glb'
# Record the native model-root world frame for independent runtime parity probes.
for f in fixtures:f['weapon_root_world']=rows(Matrix(f['weapon_body_world'])@body.matrix_world.inverted()@A.inverted())
for e in entries.values():assert hashlib.sha256((R/e['source']).read_bytes()).hexdigest()==e['source_sha256']
assert hashlib.sha256(weapon.read_bytes()).hexdigest()==wsha
ready=json.loads((D/'profile.json').read_text());assert ready['bones']==profile['bones'];assert max(abs(profile['weapon_mount'][i][j]-ready['weapon_mount'][i][j]) for i in range(4) for j in range(4))<2e-5,'Aim must use the same Rifle V2 model mount'
(S/'profile.json').write_text(json.dumps(profile,indent=2));(S/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':')))
report={'passed':True,'approved_sources_unchanged':True,'actions':[e['action'] for e in entries.values()],'maximum_carrier_to_right_arm_variation':max_grip,'total_native_samples':sum(e['samples'] for e in profile['clips'].values()),'fixtures':len(fixtures)};(S/'export_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
