import importlib,living_r9w2_common as h
importlib.reload(h)
from living_r9w2_common import *
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s)
records=json.loads((BASE/'living_r9w1_review/design.json').read_text())['actions']['LongGunAimAround_LeftRight_V1']['records'];rows=[]
for f in [1,49,73,121,145,169,217,265]:
 sample(r,s,bpy.data.actions['LongGunAimAround_LeftRight_V1'],f,True,True);pose={p.name:p.matrix_basis.copy() for p in r.pose.bones};gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();poles={side:r.pose.bones['ForeArm.'+side].head.copy() for side in ['R','L']}
 for label,angle in [('B',0),('C',12+26*records[f-1]['support_drive'])]:
  apply_pose(r,pose);targets=corrected(r,gm,poles,angle)
  rows.append({'frame':f,'variant':label,'angle':angle,'targets':targets,'contact':{side:patch_contact(r,gm,side) for side in ['R','L']},'elbow':list(r.pose.bones['ForeArm.L'].head)})
  s.camera=bpy.data.objects['R9W2_Gameplay'];s.render.filepath=str(OUT/f'gesture_{label}_{f:03}.png');bpy.ops.render.render(write_still=True)
(OUT/'gesture_probe.json').write_text(json.dumps(rows,indent=2))
