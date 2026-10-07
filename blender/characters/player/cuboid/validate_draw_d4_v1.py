"""Read evaluated Blender poses; preview overlays never add keys/NLA."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];scene=bpy.context.scene
action=bpy.data.actions['Draw_LongGun_V1'];refs=[o for o in bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].all_objects if o.type=='MESH']
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def reset():
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
def frame(f):scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def box(n):
 idx=mesh.vertex_groups[n].index;inv=rig.data.bones[n].matrix_local.inverted()@rig.matrix_world.inverted()@mesh.matrix_world
 pts=[inv@v.co for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
 return {'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)]}
lower=['Root','Hips','Leg.L','Leg.R'];upper=['Spine','Chest','Neck','Head','Arm.L','Arm.R']
geometry=[]
for o in refs:
 o.data.calc_loop_triangles();geometry.append({'vertices':[list(v.co) for v in o.data.vertices],'triangles':[list(t.vertices) for t in o.data.loop_triangles]})
samples=[];lower_error=0.0
for layer,phase in [('None',0),('Idle',0),('Run',0),('Run',4),('Run',8),('Run',12)]:
 source=bpy.data.actions['Player_Idle' if layer=='Idle' else 'Player_Run_Blocky_V7_Final'] if layer!='None' else None
 for step in range(105):
  f=1+step/8
  if source:
   sf=1+((phase+(f-1)*(1.6 if layer=='Run' else 1))%float(source.frame_range[1]-source.frame_range[0]))
   rig.animation_data.action=source;reset();frame(sf)
   base={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
  rig.animation_data.action=action;reset();frame(f)
  if source:
   for n in lower:rig.pose.bones[n].matrix_basis=base[n]
   for n in ['Spine','Chest','Neck','Head']:rig.pose.bones[n].matrix_basis=base[n]@rig.pose.bones[n].matrix_basis
   # Demonstrate phase-independent acquisition, rather than forcing Run arms.
   t=max(0,min(1,(f-1)/3));t=t*t*(3-2*t)
   for n in ['Arm.L','Arm.R']:
    p=rig.pose.bones[n];pa,qa,_=base[n].decompose();pb,qb,_=p.matrix_basis.decompose()
    m=qa.slerp(qb,t).to_matrix().to_4x4();m.translation=pa.lerp(pb,t);p.matrix_basis=m
   bpy.context.view_layer.update()
   for n in lower:lower_error=max(lower_error,max(abs(rig.pose.bones[n].matrix_basis[i][j]-base[n][i][j]) for i in range(4) for j in range(4)))
  dep=bpy.context.evaluated_depsgraph_get()
  samples.append({'layer':layer,'phase':phase,'frame':f,'body':{n:[list(row) for row in (rig.matrix_world@rig.pose.bones[n].matrix)] for n in ['Head','Chest','Arm.R','Arm.L']},'meshes':[[list(row) for row in o.evaluated_get(dep).matrix_world] for o in refs]})
rig.animation_data.action=action;reset();frame(14)
end={n:[list(row) for row in rig.pose.bones[n].matrix] for n in ['Chest','Arm.R','Arm.L','WeaponCarrier']}
keys={n:sum(len(c.keyframe_points) for c in curves(action) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in lower}
assert not any(keys.values()) and not any(c.data_path.endswith('scale') for c in curves(action))
assert not rig.data.bones['WeaponCarrier'].use_deform and lower_error<1e-6
out={'action':action.name,'frames':[1,14],'duration_seconds':13/24,'lower_keys':keys,'lower_overlay_error':lower_error,'boxes':{n:box(n) for n in ['Head','Chest','Arm.R','Arm.L']},'geometry':geometry,'samples':samples,'endpoint':end}
(BASE/'draw_d4_v1_samples.json').write_text(json.dumps(out))
frame(1)
print(json.dumps({'samples':len(samples),'lower_keys':keys,'lower_overlay_error':lower_error,'scale_keys':0}))
