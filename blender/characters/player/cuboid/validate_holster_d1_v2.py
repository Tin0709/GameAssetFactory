import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
base=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];scene=bpy.context.scene
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

report=json.loads((base/'holster_d1_v2_validation.json').read_text())
report['samples']=[];report['arm_contact_samples']=[]
angles={n:[] for n in ['Chest','Arm.L','Arm.R','Spine','Neck','Head']}
prior_q=None;max_step=0;roots=[];lowers=[]
for step in range(137):
 f=1+step*.125;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 q=rig.pose.bones['WeaponCarrier'].matrix.to_quaternion()
 if prior_q is not None:max_step=max(max_step,math.degrees(2*math.acos(min(1,abs(prior_q.normalized().dot(q.normalized()))))))
 prior_q=q
 roots.append(list(rig.pose.bones['Root'].matrix.translation))
 lowers.append(max((rig.pose.bones[n].matrix_basis-Matrix.Identity(4)).to_3x3().magnitude if False else sum(abs(rig.pose.bones[n].matrix_basis[i][j]-(1 if i==j else 0)) for i in range(4) for j in range(4)) for n in ['Root','Hips','Leg.L','Leg.R']))
 for n in angles:angles[n].append([math.degrees(a) for a in rig.pose.bones[n].rotation_euler])
 report['samples'].append({'frame':f,'carrier_position':list(rig.pose.bones['WeaponCarrier'].matrix.translation)})
 armcounts={n:0 for n in ['Arm.L','Arm.R']}
 dep=bpy.context.evaluated_depsgraph_get()
 for n in armcounts:
  lo,hi=part_box(n);margin=Vector((.025,)*3);low=lo+margin;high=hi-margin;high.y-=.20
  inv=(rig.matrix_world@rig.pose.bones[n].matrix).inverted()
  for obj in ref_meshes:
   world=obj.evaluated_get(dep).matrix_world;v=[inv@(world@v.co) for v in obj.data.vertices]
   armcounts[n]+=sum(tri_box([v[j] for j in t.vertices],low,high) for t in obj.data.loop_triangles)
 if any(armcounts.values()):report['arm_contact_samples'].append({'frame':f,'triangles':armcounts})
report['pose_local_euler_XYZ_deg_ranges']={n:[[min(a[i] for a in values),max(a[i] for a in values)] for i in range(3)] for n,values in angles.items()}
report['root_travel_m']=max((Vector(p)-Vector(roots[0])).length for p in roots)
report['lower_body_basis_max_error']=max(lowers)
report['carrier_max_angular_step_deg_per_eighth_frame']=max_step
report['arm_clearance_refinements']={10.6:[0,10,0],12.9:[20,10,20],14.3:[8,5,8]}
scene.frame_set(1)
(base/'holster_d1_v2_validation.json').write_text(json.dumps(report,indent=2))
result={k:v for k,v in report.items() if k in ['root_travel_m','lower_body_basis_max_error','carrier_max_angular_step_deg_per_eighth_frame','pose_local_euler_XYZ_deg_ranges']}
result['right_arm_contact_sample_count']=len(report['arm_contact_samples'])
