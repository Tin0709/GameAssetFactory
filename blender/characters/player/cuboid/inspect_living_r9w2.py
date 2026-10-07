import living_r9w2_common as h
from living_r9w2_common import *
p=OUT/'preservation.json'
if not p.exists():
 old=json.loads((BASE/'living_r9w1_review/preservation.json').read_text())
 files=old['files'].copy()
 for f in list(BASE.glob('*r9w1*'))+list((BASE/'living_r9w1_review').rglob('*')):
  if f.is_file():files[str(f.relative_to(ROOT))]=hashlib.sha256(f.read_bytes()).hexdigest()
 p.write_text(json.dumps({'files':files,'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'}},indent=2))
s=scene('R9W2_DIAGNOSIS');bpy.context.window.scene=s;r,mp=clone2('Probe',s);w=gun(s);m=mp[bpy.data.objects['R9W1_Author_Mesh']]
for view in ['Gameplay','Close','Side','Opposite','Distance']:
 c=bpy.data.objects['R9W1_'+view].copy();c.data=c.data.copy();c.name='R9W2_'+view;s.collection.objects.link(c)
s.camera=bpy.data.objects['R9W2_Gameplay'];s.eevee.taa_render_samples=16
states=[]
for label,an,frame,stationary in [('Ready','LongGunReady_LivingRef_V1',25,True),('Left','LongGunAimAround_LeftRight_V1',73,True),('Reverse','LongGunAimAround_LeftRight_V1',145,True),('Right','LongGunAimAround_LeftRight_V1',217,True),('WalkLeft','LongGunAimAround_LeftRight_V1',73,False),('WalkReverse','LongGunAimAround_LeftRight_V1',145,False),('WalkRight','LongGunAimAround_LeftRight_V1',217,False)]:
 sample(r,s,bpy.data.actions[an],frame,True,stationary);pose={pb.name:pb.matrix_basis.copy() for pb in r.pose.bones};apply_pose(r,pose)
 wm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
 states.append({'label':label,'frame':frame,'elbow':list(r.pose.bones['ForeArm.L'].head),'hand_local':list(wm.inverted()@(r.pose.bones['ForeArm.L'].matrix@Vector((0,.2625,0))))})
 for view in ['Gameplay','Close']:
  s.camera=bpy.data.objects['R9W2_'+view];s.render.filepath=str(OUT/f'before_{label}_{view}.png');bpy.ops.render.render(write_still=True)
(OUT/'before.json').write_text(json.dumps(states,indent=2));save()
