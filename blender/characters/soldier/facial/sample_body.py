"""Sample existing body Actions read-only for facial compatibility previews only."""
from pathlib import Path
import bpy,json,hashlib,math
D=Path(__file__).resolve().parent;R=D.parents[3]
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())['animations']
choices={'Idle':('Idle_ActionsStuff_Source_Test_v001',9.),'Walk':('Walk_ActionsStuff_Source_Test_v001',4.),'Run':('Run_ActionsStuff_Source_Test_v001',6.),'Rifle Ready Idle':('Rifle_Ready_Idle_ActionsStyle_v004',7.2),'Aim':('Crossbow_Aim_ActionsStuff_Refined_Test_v001',3.6),'Fire':('Rifle_Fire_Recoil_ActionsStyle_v001',1/6),'Jump':('Jump_ActionsStuff_Source_Test_v001',1.2),'Landing':('Landing_Stationary_ActionsStuff_Source_Test_v001',1.)}
names=['Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R'];aliases={'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}
result={}
for mode,(name,length) in choices.items():
 e=next(e for e in manifest if e['action']==name);path=R/e['source'];sha=hashlib.sha256(path.read_bytes()).hexdigest()
 bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False);scene=bpy.context.scene;rig=bpy.data.objects[e['source_rig']];action=bpy.data.actions[name]
 rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0];scene['gaf_library_last_action']=action.name
 clip_length=(e['end']+1-e['start'])/30;frames=[]
 for i in range(round(length*30)+1):
  t=i/30;st=min(t,clip_length-1/3000) if mode in ['Jump','Landing'] else t%clip_length
  frame=e['start']+st*30;scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
  poses={}
  for n in names:
   b=rig.pose.bones.get(aliases.get(n,n)) or rig.pose.bones.get(n)
   assert b is not None,(mode,n);poses[n]=[round(v,8) for row in b.matrix for v in row]
  carrier=rig.pose.bones.get('WeaponCarrier');poses['Weapon']=[round(v,8) for row in carrier.matrix for v in row] if carrier else None
  frames.append(poses)
 assert hashlib.sha256(path.read_bytes()).hexdigest()==sha
 result[mode]={'source':e['source'],'sha256':sha,'action':name,'length':length,'source_cycle_s':clip_length,'fps':30,'frames':frames,'research_only':True,'preview_only':True}
 print('SAMPLED',mode,len(frames),flush=True)
(D/'body_preview_samples.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
print('BODY_SAMPLES_DONE',flush=True)
