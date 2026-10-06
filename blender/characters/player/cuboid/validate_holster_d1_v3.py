import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];scene=bpy.context.scene
def curves(a):return [c for l in a.layers for st in l.strips for bag in st.channelbags for c in bag.fcurves]
ref_meshes=[o for o in bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].all_objects if o.type=='MESH']
def part_box(name):
 idx=mesh.vertex_groups[name].index;inv=rig.data.bones[name].matrix_local.inverted()
 points=[inv@(mesh.matrix_world@v.co) for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
 return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))
boxes={n:part_box(n) for n in ['Head','Chest']}
def tri_box(points,low,high):
 center=(low+high)*.5;extent=(high-low)*.5;v=[p-center for p in points]
 edges=[v[1]-v[0],v[2]-v[1],v[0]-v[2]]
 axes=[Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)),edges[0].cross(edges[1])]
 axes += [e.cross(a) for e in edges for a in axes[:3]]
 for a in axes:
  if a.length_squared<1e-12:continue
  p=[a.dot(q) for q in v];r=sum(extent[i]*abs(a[i]) for i in range(3))
  if min(p)>r or max(p)<-r:return False
 return True

for obj in ref_meshes:obj.data.calc_loop_triangles()
allboxes={n:part_box(n) for n in ['Head','Chest','Arm.L','Arm.R']}
def inspect_pose():
 dep=bpy.context.evaluated_depsgraph_get();hits={};depths={}
 for n,(lo,hi) in allboxes.items():
  margin=.010 if n=='Head' else .035 if n=='Chest' else .025
  low=lo+Vector((margin,)*3);high=hi-Vector((margin,)*3)
  if n.startswith('Arm.'):high.y-=.20
  inv=(rig.matrix_world@rig.pose.bones[n].matrix).inverted();count=0;depth=0
  for obj in ref_meshes:
   mat=inv@obj.evaluated_get(dep).matrix_world;v=[mat@v.co for v in obj.data.vertices]
   count+=sum(tri_box([v[j] for j in t.vertices],low,high) for t in obj.data.loop_triangles)
   for p in v:
    if all(low[i]<p[i]<high[i] for i in range(3)):
     depth=max(depth,min(min(p[i]-low[i],high[i]-p[i]) for i in range(3)))
  hits[n]=count;depths[n]=depth
 return hits,depths
report={'action':'Holster_LongGun_V3_Final','frames':[1,18],'fps':24,'duration_seconds':17/24,'samples_per_action':137,'versions':{}}
for an in ['Holster_LongGun_V2','Holster_LongGun_V3_Final']:
 rig.animation_data.action=bpy.data.actions[an]
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 samples=[];previous=None
 for step in range(137):
  f=1+step*.125;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  hits,depths=inspect_pose()
  carrier=rig.pose.bones['WeaponCarrier'].matrix.copy();q=carrier.to_quaternion().normalized()
  speed=0;angular=0
  if previous is not None:
   speed=(carrier.translation-previous[0]).length*192
   angular=math.degrees(2*math.acos(min(1,abs(q.dot(previous[1])))))*192
  previous=(carrier.translation.copy(),q)
  samples.append({'frame':f,'contacts':hits,'depth_in_shrunken_box_m':depths,'carrier_position':list(carrier.translation),'carrier_speed_m_s':speed,'carrier_angular_speed_deg_s':angular,'pose_euler_deg':{n:[math.degrees(a) for a in rig.pose.bones[n].rotation_euler] for n in ['Chest','Spine','Neck','Head','Arm.L','Arm.R']}})
 report['versions'][an]={'samples':samples,'right_arm_contact_samples':sum(p['contacts']['Arm.R']>0 for p in samples),'right_arm_triangle_contact_sum':sum(p['contacts']['Arm.R'] for p in samples),'right_arm_max_depth_m':max(p['depth_in_shrunken_box_m']['Arm.R'] for p in samples),'head_or_deep_chest_hits':[{'frame':p['frame'],'Head':p['contacts']['Head'],'Chest':p['contacts']['Chest']} for p in samples if p['contacts']['Head'] or p['contacts']['Chest']],'max_carrier_speed_m_s':max(p['carrier_speed_m_s'] for p in samples),'max_carrier_angular_speed_deg_s':max(p['carrier_angular_speed_deg_s'] for p in samples)}
rig.animation_data.action=bpy.data.actions['Holster_LongGun_V3_Final'];scene.frame_set(1)
(BASE/'holster_d1_v3_validation.json').write_text(json.dumps(report,indent=2))
result={n:{k:v for k,v in info.items() if k!='samples'} for n,info in report['versions'].items()}

