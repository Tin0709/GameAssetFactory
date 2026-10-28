import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix,Vector
H=Path(__file__).resolve().parent;R=H.parents[4];sys.path.insert(0,str(H));import motion as m
meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'));rig=bpy.data.objects[meta['rig']];mesh=bpy.data.objects[meta['mesh']];scene=bpy.context.scene
rest={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones};points={}
for name in ['Leg.L','Leg.R']:
 idx=mesh.vertex_groups[name].index;points[name]=[v.co.copy()for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
def sample(t):f=1+t*60;scene.frame_set(int(f),subframe=f%1)
def mats():return {b.name:b.matrix.copy()for b in rig.pose.bones}
def error(a,b):return max(abs(a[n][i][j]-b[n][i][j])for n in a for i in range(4)for j in range(4))
results=[];endpoints={}
for spec in meta['specs']:
 a=bpy.data.actions[spec['action']];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];phase=spec['phase'];duration=spec['duration']
 scales=[];helpers=[];floor=[];contacts=[];hips=[];head=[];contactpoints=[];swing_pen=[];root=[]
 for j in range(2001):
  t=j*duration/2000;sample(t);elevation=m.elevation(t)if phase=='context'else 0.;ground=phase=='landing'or(phase=='context'and(t<m.START or t>=m.START+m.FLIGHT))
  hips.append(rig.pose.bones['Hips'].matrix.translation.z)
  head.append(abs(math.degrees((rig.pose.bones['Head'].matrix.to_3x3()@rest['Head'].to_3x3().inverted()).to_euler('XYZ').x)))
  root.append(rig.pose.bones['Root'].matrix.translation.length)
  for b in rig.pose.bones:
   scales.append(max(abs(v-1)for v in b.scale))
   if b.name.startswith('ForeArm'):helpers.append(max(abs(b.matrix_basis[i][k]-Matrix.Identity(4)[i][k])for i in range(4)for k in range(4)))
  for name,verts in points.items():
   skin=rig.pose.bones[name].matrix@rest[name].inverted();vs=[skin@v+Vector((0,0,elevation))for v in verts];minimum=min(v.z for v in vs);floor.append(minimum)
   if ground:
    sole=[skin@v+Vector((0,0,elevation))for v in verts if v.z<1e-5];contactpoints.append((name,t,sum(sole,Vector())/len(sole)))
    contacts.append(minimum)
   elif phase=='context':swing_pen.append(max(0.,-minimum))
 speeds=[]
 for name in points:
  rows=[v for v in contactpoints if v[0]==name]
  for a1,b1 in zip(rows,rows[1:]):
   if b1[1]-a1[1]<.002:speeds.append((b1[2]-a1[2]).length/(b1[1]-a1[1]))
 sample(0);first=mats();sample(duration);last=mats();endpoints[phase]=(first,last)
 rate_checks=[]
 for hz in (30,60,120):
  lastpos=None;maxstep=0;max_ground_pen=0
  for j in range(round(duration*hz)+1):
   t=min(duration,j/hz);sample(t);cur=rig.pose.bones['Hips'].matrix.translation.copy()
   if lastpos is not None:maxstep=max(maxstep,(cur-lastpos).length)
   lastpos=cur
   if phase=='context':
    for name,verts in points.items():
     skin=rig.pose.bones[name].matrix@rest[name].inverted();max_ground_pen=max(max_ground_pen,max(0.,-min((skin@v).z+m.elevation(t)for v in verts)))
  rate_checks.append({'hz':hz,'maximum_hip_origin_step_mm':maxstep*1000,'context_penetration_mm':max_ground_pen*1000})
 result={'action':spec['action'],'phase':phase,'duration_s':duration,'hip_range_mm':(max(hips)-min(hips))*1000,'head_global_pitch_max_deg':max(head),'scale_error':max(scales),'forearm_identity_error':max(helpers),'root_travel_m':max(root),'minimum_in_place_sole_z_m':min(floor),'ground_penetration_mm':max(0.,-min(contacts))*1000 if contacts else None,'air_penetration_in_context_mm':max(swing_pen,default=0)*1000,'grounded_sole_velocity_max_m_s':max(speeds,default=0),'loop_pose_error':error(first,last)if spec['loop']or phase=='context'else None,'review_rates':rate_checks}
 results.append(result);print(json.dumps(result),flush=True)
 assert max(scales)<1e-6 and max(helpers)<1e-5 and max(root)<1e-6
 if contacts:assert min(contacts)>-.0005 and max(speeds,default=0)<.01,result
 if phase=='context':assert max(swing_pen,default=0)<.0005,result
 if spec['loop']:assert error(first,last)<1e-5
boundaries={'takeoff_to_airborne_pose_error':error(endpoints['takeoff'][1],endpoints['airborne'][0]),'landing_to_context_hold_pose_error':error(endpoints['landing'][1],endpoints['context'][1])}
assert max(boundaries.values())<1e-5,boundaries
(H/'measurements.json').write_text(json.dumps({'scope':'Actually evaluated saved original Actions and actual rigid sole geometry. Source-authored references not sampled. Preview arc is original adapter, not native physics.','metrics':results,'phase_boundaries':boundaries},indent=2),encoding='utf8')
print('ORIGINAL_JUMP_MEASURED',flush=True)
