layer_source=globals().get('layer_source','Run')
run_phase=globals().get('run_phase',0)
import bpy,json,math
from mathutils import Matrix,Vector
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
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

source_name='Player_Idle' if layer_source=='Idle' else 'Player_Run_Blocky_V7_Final'
source=bpy.data.actions[source_name];final=bpy.data.actions['Holster_LongGun_V3_Final']
start,end=source.frame_range;period=end-start
lower=['Root','Hips','Leg.L','Leg.R'];upper=['Spine','Chest','Neck','Head','Arm.L','Arm.R']
def blend_basis(a,b,t):
 pa,qa,sa=a.decompose();pb,qb,sb=b.decompose()
 if qa.dot(qb)<0:qb.negate()
 m=qa.slerp(qb,t).to_matrix().to_4x4();m.translation=pa.lerp(pb,t);return m
frames=range(1,23)
hits=[];samples=[];reset_errors=[]
folder=BASE/'holster_d1_v3_review'
for hf in frames:
 rate=1.0 if layer_source=='Idle' else 1.60
 sf=start+(((hf-1)*rate+run_phase)%period)
 rig.animation_data.action=source
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 scene.frame_set(int(sf),subframe=sf-int(sf));bpy.context.view_layer.update()
 source_pose={n:rig.pose.bones[n].matrix_basis.copy() for n in lower+upper}
 rig.animation_data.action=final
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 f=min(hf,18);scene.frame_set(f);bpy.context.view_layer.update()
 for n in lower:rig.pose.bones[n].matrix_basis=source_pose[n]
 if hf>18:
  t=(hf-18)/4
  for n in upper:rig.pose.bones[n].matrix_basis=blend_basis(rig.pose.bones[n].matrix_basis,source_pose[n],t)
 bpy.context.view_layer.update()
 deps=bpy.context.evaluated_depsgraph_get();counts={}
 for n,(lo,hi) in boxes.items():
  margin=.01 if n=='Head' else .035;inv=(rig.matrix_world@rig.pose.bones[n].matrix).inverted();count=0
  for obj in ref_meshes:
   world=obj.evaluated_get(deps).matrix_world;v=[inv@(world@v.co) for v in obj.data.vertices]
   count+=sum(tri_box([v[j] for j in t.vertices],lo+Vector((margin,)*3),hi-Vector((margin,)*3)) for t in obj.data.loop_triangles)
  counts[n]=count
 if any(counts.values()):hits.append({'holster_frame':hf,'source_frame':sf,'parts':counts})
 samples.append({'holster_frame':hf,'source_frame':sf,'hips_location':list(rig.pose.bones['Hips'].location),'root':list(rig.pose.bones['Root'].matrix.translation)})
 scene.camera=bpy.data.objects['D1_Gameplay']
 scene.render.filepath=str(folder/('overlay_%s_phase%02d_frame%02d.png'%(layer_source.lower(),run_phase,hf)))
 bpy.ops.render.render(write_still=True)
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
rig.animation_data.action=final;scene.frame_set(1);bpy.context.view_layer.update()
report={'source':source_name,'speed_scale':1.0 if layer_source=='Idle' else 1.60,'phase':run_phase,'frames':22,'exit_blend_frames':4,'head_or_deep_chest_hits':hits,'samples':samples,'no_NLA_added':True}
(BASE/('holster_d1_v3_overlay_%s_phase%02d.json'%(layer_source.lower(),run_phase))).write_text(json.dumps(report,indent=2))
result={k:v for k,v in report.items() if k!='samples'}

