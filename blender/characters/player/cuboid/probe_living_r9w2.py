"""Contact-first diagnostic poses; no Actions are authored by this probe."""
import importlib,living_r9w2_common as h
importlib.reload(h)
from living_r9w2_common import *
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s);m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name)
sample(r,s,bpy.data.actions['LongGunAimAround_LeftRight_V1'],73,True,True);original_pose={p.name:p.matrix_basis.copy() for p in r.pose.bones};gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gm
boxes=boxes_for(r,m,.005)
def solve_contacts(r,gm,poles):
 targets={}
 for side in ['R','L']:
  target=Vector((-.13,-.015,.012)) if side=='R' else Vector((-.11,.36,.015))
  for _ in range(12):
   arm(r,side,gm@target,poles[side],gm.to_3x3()@Vector((1,0,0)))
   fo=r.pose.bones['ForeArm.'+side]
   corners=[gm.inverted()@(fo.matrix@Vector((x,y,z))) for x in [-.1125,.1125] for y in [.1875,.3375] for z in [-.1125,.1125]]
   if side=='L':target.z+=.122-max(p.z for p in corners)
   else:target.x+=-.033-max(p.x for p in corners)
  targets[side]=list(target)
 return targets
report=[]
for label,offset in [('original',(0,0,0)),('contact',(0,0,0)),('contact_forward',(0,.025,0))]:
 apply_pose(r,original_pose);g=gm@Matrix.Translation(Vector(offset));r.pose.bones['WeaponCarrier'].matrix=g@socket.inverted();bpy.context.view_layer.update()
 poles={side:r.pose.bones['ForeArm.'+side].head.copy() for side in ['R','L']};poles['R']+=Vector((0,.2,0))
 targets=None
 if label!='original':targets=solve_contacts(r,g,poles)
 report.append({'label':label,'targets':targets,'contacts':{n:contact(r,w,n,boxes) for n in ['Head','Chest','UpperArm.R','ForeArm.R','ForeArm.L']},'shoulders':{side:list(r.pose.bones['UpperArm.'+side].head) for side in ['R','L']}})
 for view in ['Gameplay','Close','Side','Opposite']:
  s.camera=bpy.data.objects['R9W2_'+view];s.render.filepath=str(OUT/f'probe_{label}_{view}.png');bpy.ops.render.render(write_still=True)
(OUT/'contact_probe.json').write_text(json.dumps(report,indent=2))



