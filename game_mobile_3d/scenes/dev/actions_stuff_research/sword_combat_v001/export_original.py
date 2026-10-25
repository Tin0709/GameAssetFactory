"""Read-only evaluated Sword original PRS export; follows rifle_ready exporter basis.
Raw samples/fixtures live only in --stage; runtime gets compressed library/profile.
"""
import bpy,sys,json,math,hashlib,struct,argparse,shutil
from pathlib import Path
from mathutils import Matrix,Vector
opt=argparse.ArgumentParser();opt.add_argument('--stage',required=True);args=opt.parse_args(sys.argv[sys.argv.index('--')+1:])
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());D=Path(__file__).resolve().parent;S=Path(args.stage);S.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
study=R/'blender/animation/reviews/player_animation_library_v1/sword_combat_v001';design=json.loads((study/'design.json').read_text());source=R/design['source'];sha=hashlib.sha256(source.read_bytes()).hexdigest();assert sha==design['source_sha256']
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False);scene=bpy.data.scenes['SWORD_COMBAT_ORIGINAL_V001_REVIEW'];bpy.context.window.scene=scene;rig=bpy.data.objects[design['source_rig']];mesh=bpy.data.objects[design['source_mesh']]
A=Matrix.Rotation(-math.pi/2,4,'X');aliases={'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'};names=[b.name for b in rig.data.bones];rows=lambda m:[list(row) for row in m]
profile={'schema':1,'status':'pending','research_only':True,'production_eligible':False,'original_custom_animation':True,'source_derived_reconstruction':False,'bones':[aliases.get(n,n) for n in names],'rig_sha256':ui.rest_signature(rig.data),'clips':{},'sword_asset':'res://scenes/dev/actions_stuff_research/sword_combat_v001/assets/Sword_Sand_Block_V1.glb','weapon_mount':rows(A.inverted()),'sword_base_local':[0,0,-.1596],'sword_tip_local':[0,0,-.96292],'blade_base_local':[0,0,-.1596],'blade_tip_local':[0,0,-.96292],'weapon_source_sha256':hashlib.sha256((R/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.blend').read_bytes()).hexdigest(),'weapon_glb_sha256':hashlib.sha256((R/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.glb').read_bytes()).hexdigest(),'world_travel_owner':'physics','roll_root_translation':'Original local pelvis pivot and support compensation only. Do not add it to CharacterBody3D travel.','provenance':design['provenance'],'original_combo_source':design['original_combo_source'],'original_combo_source_sha256':design['original_combo_source_sha256'],'original_combo_action_sha256':design['original_combo_action_sha256']}
C=None;max_grip=0.;max_scale=0.;fixtures=[]
for kind,e in design['clips'].items():
 action=bpy.data.actions[e['action']];assert ui.action_signature(action)==e['action_sha256'];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 times=sorted({round((float(k.co.x)-1)/30,10) for c in ui.curves(action) for k in c.keyframe_points}|{0.,e['duration']});times=[min(max(0,t),e['duration']) for t in times];times=sorted(set(times))
 previous={};samples=[]
 for i,t in enumerate(times):
  f=1+t*30;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in rig.pose.bones};rel=M['UpperArm.R'].inverted()@M['WeaponCarrier']
  if C is None:C=rel.copy()
  max_grip=max(max_grip,max(abs(rel[a][b]-C[a][b]) for a in range(4) for b in range(4)))
  data=[t];poses={}
  for b in rig.data.bones:
   local=M[b.parent.name].inverted()@M[b.name] if b.parent else A@M[b.name];p,q,scale=local.decompose()
   if b.name in previous and q.dot(previous[b.name])<0:q.negate()
   previous[b.name]=q.copy();max_scale=max(max_scale,max(abs(v-1) for v in scale));values=[*p,q.x,q.y,q.z,q.w,*scale];data+=values;poses[aliases.get(b.name,b.name)]=values
  samples.append(data)
  if i in {0,len(times)//4,len(times)//2,3*len(times)//4,len(times)-1}:fixtures.append({'clip':kind,'time':t,'poses':poses,'blade_tip_world':list(A@(M['WeaponCarrier']@Vector((0,.96292,0)))),'blade_base_world':list(A@(M['WeaponCarrier']@Vector((0,.1596,0))))})
 raw=S/(kind.lower()+'.bin')
 with raw.open('wb') as f:
  for row in samples:f.write(struct.pack('<'+'f'*len(row),*row))
 profile['clips'][kind]={'action':e['action'],'duration':e['duration'],'loop':e['loop'],'samples':len(samples),'row_floats':len(samples[0]),'raw_file':raw.name,'source':design['source'],'source_sha256':sha,'action_sha256':e['action_sha256'],'original_source_frames':e['source_frames'],'contact_time':design['contact_seconds'].get(kind,-1),'entry_exit':design['entry_exit'][kind]}
 print('EXPORTED',kind,len(samples),flush=True)
profile['carrier_in_right_arm']=rows(C)
assert max_grip<2e-5,(max_grip,'grip mismatch');assert max_scale<3e-6,max_scale
for name in ['Sword_Sand_Block_V1.glb','sword_sand_atlas_256.png']:shutil.copy2(R/'blender/weapons/sword_sand_block_v1'/name,D/'assets'/name)
(S/'profile.json').write_text(json.dumps(profile,indent=2)+'\n');(S/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
report={'passed':True,'clip_count':8,'samples':sum(v['samples'] for v in profile['clips'].values()),'maximum_carrier_in_right_arm_matrix_error':max_grip,'maximum_scale_error':max_scale,'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==sha,'basis':'Root = RotX(-pi/2) * evaluated Blender root. Children evaluated parent^-1 * child, full local PRS.'}
(S/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SWORD_EXPORT',json.dumps(report),flush=True)
