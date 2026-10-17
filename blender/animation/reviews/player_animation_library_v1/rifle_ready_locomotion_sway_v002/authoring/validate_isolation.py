"""Independent paired evaluation of the saved candidate and approved bases."""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
r=bpy.data.objects[ui.RIG];s=bpy.context.scene
entries=json.loads((O/'entries.json').read_text());manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def pose(a,f):
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 return {b.name:b.matrix.copy() for b in r.pose.bones}
reports=[]
for e in entries:
 a=bpy.data.actions[e['action']];base=bpy.data.actions[e['refinement_base']];old=next(x for x in manifest['animations'] if x['action']==base.name)
 assert ui.action_signature(base)==old['action_sha256'];assert ui.action_signature(a)==e['action_sha256']
 modified={('Chest','rotation_quaternion'),('Head','rotation_quaternion')}
 if 'Run' in a.name:modified|={(n,'location') for n in ['UpperArm.L','UpperArm.R','WeaponCarrier']}
 allowed={r.pose.bones[n].path_from_id(p) for n,p in modified}
 def data(c):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]
 ref={(c.data_path,c.array_index):c for c in ui.curves(base)};untouched=0
 for c in ui.curves(a):
  if c.data_path not in allowed:assert data(c)==data(ref[c.data_path,c.array_index]),c.data_path;untouched+=1
 end=e['endpoint_sample_frame'];frames=sorted({1+(end-1)*i/40 for i in range(41)}|{1.,float(end)}|({95.5,143.} if 'Walk' in a.name else {341.,369.}))
 metrics={'head_world_matrix_error':0.,'chest_bounce_position_error_m':0.,'lower_body_world_matrix_error':0.,'right_shoulder_chest_local_error_m':0.,'left_shoulder_chest_local_shift_m':0.}
 for f in frames:
  B=pose(base,f);M=pose(a,f)
  metrics['head_world_matrix_error']=max(metrics['head_world_matrix_error'],md(M['Head'],B['Head']))
  metrics['chest_bounce_position_error_m']=max(metrics['chest_bounce_position_error_m'],(M['Chest'].translation-B['Chest'].translation).length)
  for n in ['Root','Hips','Spine','Leg.L','Leg.R']:metrics['lower_body_world_matrix_error']=max(metrics['lower_body_world_matrix_error'],md(M[n],B[n]))
  for side,key in [('R','right_shoulder_chest_local_error_m'),('L','left_shoulder_chest_local_shift_m')]:metrics[key]=max(metrics[key],(M['Chest'].inverted()@M['UpperArm.'+side].translation-B['Chest'].inverted()@B['UpperArm.'+side].translation).length)
 assert metrics['head_world_matrix_error']<1e-5 and metrics['chest_bounce_position_error_m']<1e-5 and metrics['lower_body_world_matrix_error']<1e-6
 seat=abs(e['holding_sway']['holding_seat_m']);assert max(metrics['right_shoulder_chest_local_error_m'],metrics['left_shoulder_chest_local_shift_m'])<seat+1e-5
 reports.append({'action':a.name,'passed':True,'paired_poses':len(frames),'untouched_curves_exact':untouched,'metrics':metrics});print(json.dumps(reports[-1]),flush=True)
(O/'isolation_validation.json').write_text(json.dumps({'passed':True,'reports':reports},indent=2)+'\n')
# Replace intermediate build measurements with these independently measured
# final saved-file values; no animation content is changed by this audit.
build=json.loads((O/'build_validation.json').read_text())
for row in build['reports']:
 row['metrics']=next(x['metrics'] for x in reports if x['action']==row['action'])
(O/'build_validation.json').write_text(json.dumps(build,indent=2)+'\n')
