"""Measure reopened keyed rig and actual rigid sole geometry, not equations alone."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
H=Path(__file__).resolve().parent;R=H.parents[4];sys.path.insert(0,str(H));import motion as m
meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'))
rig=bpy.data.objects[meta['rig']];mesh=bpy.data.objects[meta['mesh']];scene=bpy.context.scene
rest={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones}
feet={}
for name in ['Leg.L','Leg.R']:
 idx=mesh.vertex_groups[name].index
 feet[name]=[v.co.copy()for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
def sample(frame):scene.frame_set(int(frame),subframe=frame%1)
def stats(values):return {'rms':math.sqrt(sum(v*v for v in values)/len(values)),'max':max(values)}if values else None
results=[]
for spec in meta['specs']:
 action=bpy.data.actions[spec['action']];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 style=spec.get('style');transition=bool(spec.get('preview_only'))
 rows=json.loads((H/'transition_trace.json').read_text(encoding='utf8'))if transition else None
 count=len(rows)if transition else 1601
 hips=[];heads=[];torso=[];roots=[];penetration=[];contact=[];allground=[];offsets=[];scales=[];forearms=[];origins=[]
 for j in range(count):
  if transition:row=rows[j];f=row['frame'];t=row['time'];travel=row['travel_m'];phase=row['phase'];s=m.blend_style(row['run_weight'])
  else:
   t=j/(count-1)/style['hz'];f=1+t*m.FPS;travel=style['speed']*t;phase=(m.ORIGIN+t*style['hz'])%1;s=style
  sample(f);hip=rig.pose.bones['Hips'].matrix.translation.copy();hips.append(hip.z)
  head=rig.pose.bones['Head'].matrix.to_3x3()@rest['Head'].to_3x3().inverted();heads.append([math.degrees(x)for x in head.to_euler('XYZ')])
  torso.append(math.degrees((rig.pose.bones['Chest'].matrix.to_3x3()@rest['Chest'].to_3x3().inverted()).to_euler('XYZ').z))
  origins.append([t,{b.name:list(b.matrix.translation)for b in rig.pose.bones}])
  roots.append(rig.pose.bones['Root'].matrix.translation.length)
  for b in rig.pose.bones:
   scales.append(max(abs(v-1)for v in b.scale))
   if b.name.startswith('ForeArm'):forearms.append(max(abs(b.matrix_basis[x][y]-Matrix.Identity(4)[x][y])for x in range(4)for y in range(4)))
  for name,verts in feet.items():
   mat=rig.pose.bones[name].matrix@rest[name].inverted();actual=[mat@v for v in verts];minz=min(v.z for v in actual);penetration.append(max(0.,-minz))
   offsets.append(rig.pose.bones[name].matrix.translation.z-hip.z)
   if transition:plant=row['contacts'][name]['plant'];corner=row['contacts'][name]['corner']
   else:_,plant,corner=m.leg(phase if name.endswith('L')else(phase+.5)%1,s)
   if plant:
    edge=[mat@v for v in verts if abs(v.z)<1e-5 and abs(v.y-corner)<1e-5]
    assert len(edge)==2
    pt=sum(edge,Vector())/2;pt.y-=travel
    contact.append({'bone':name,'corner':corner,'t':t,'pos':list(pt)})
   # Retain actual lowest geometry during every near-ground sample separately.
   if minz<.02:
    v=min(actual,key=lambda v:v.z).copy();v.y-=travel
    allground.append({'bone':name,'t':t,'pos':list(v),'plant':plant})
 speeds=[]
 for name in feet:
  values=[r for r in contact if r['bone']==name]
  for a,b in zip(values,values[1:]):
   if 0<b['t']-a['t']<.003 and a['corner']==b['corner']:speeds.append((Vector(a['pos'])-Vector(b['pos'])).length/(b['t']-a['t']))
 # Explicit pose seam for looping clips; transition is a finite test take.
 seam=None;velocity_seam=None
 if style:
  def positions(f):sample(f);return {b.name:b.matrix.copy()for b in rig.pose.bones}
  start=positions(1);end=positions(1+m.FPS/style['hz'])
  seam=max(abs(start[n][x][y]-end[n][x][y])for n in start for x in range(4)for y in range(4))
  delta=.01
  after=positions(1+delta);before=positions(1+m.FPS/style['hz']-delta)
  velocity_seam=max(((after[n].translation-start[n].translation)-(end[n].translation-before[n].translation)).length/(delta/m.FPS)for n in start)
 # Finite output step at requested review rates, no physics/controller claims.
 rate_checks=[]
 for hz in (30,60,120):
  maxstep=0.;last=None
  for i in range(int((spec['end']/60)*hz)+1):
   sample(1+i/hz*60);cur={b.name:b.matrix.translation.copy()for b in rig.pose.bones}
   if last:maxstep=max(maxstep,max((cur[n]-last[n]).length for n in cur))
   last=cur
  rate_checks.append({'review_hz':hz,'max_bone_origin_step_m':maxstep})
 result={'action':action.name,'original_authored':True,'pending':True,'gait_hz':style['hz']if style else 'continuous 1.2 to 1.6','nominal_speed_m_s':style['speed']if style else [1.8,4.3],'cycle_stride_m':style['speed']/style['hz']if style else None,'hip_peak_to_peak_mm':(max(hips)-min(hips))*1000,'hip_height_m':[min(hips),max(hips)],'chest_yaw_peak_to_peak_deg':max(torso)-min(torso),'head_global_rotation_peak_abs_deg':[max(abs(v[k])for v in heads)for k in range(3)],'rolling_contact_velocity_m_s':stats(speeds),'rolling_contact_velocity_samples':len(speeds),'max_penetration_mm':max(penetration)*1000,'leg_hip_origin_vertical_difference_mm':[min(offsets)*1000,max(offsets)*1000],'max_scale_error':max(scales),'forearm_basis_error':max(forearms),'root_travel_m':max(roots),'pose_cycle_error':seam,'finite_bake_velocity_seam_m_s':velocity_seam,'playback_rate_measurements':rate_checks,'contact_schedule':'original intent, not source mask','near_ground_sample_count':len(allground)}
 results.append(result);print(json.dumps(result),flush=True)
 assert max(penetration)<.001 and max(scales)<1e-6 and max(forearms)<1e-5
 assert result['rolling_contact_velocity_m_s']['max']<.065,result
 if seam is not None:assert seam<1e-4,result
(H/'measurements.json').write_text(json.dumps({'scope':'Reopened actual source; unit-scale rigid limbs, in-place Root, original rolling-edge contact intent. Transition anchor construction is original offline preview logic. Not native A&S foot IK, Godot integration, or arbitrary-speed validation.','metrics':results},indent=2),encoding='utf8')
print('MEASURED_ALL',len(results),flush=True)
