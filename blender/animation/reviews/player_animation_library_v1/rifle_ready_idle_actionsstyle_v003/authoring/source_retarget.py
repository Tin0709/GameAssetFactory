"""Literal source PRS -> unchanged native rig; declared rifle/contact/floor adapters only."""
import sys,math
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file())
sys.path.insert(0,str(ROOT/'blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001'))
from idle_retarget import JumpRetarget
class RifleRetarget:
 def __init__(self,rig,mesh,approved,initial,weapon_geometry):
  self.rig=rig;self.mesh=mesh;self.B=approved;self.weapons=weapon_geometry;self.mapper=JumpRetarget(rig);self.N=self.mapper.base
  self.raw0=self.mapper.desired(initial,entity_head=True)
  self.body0=self.raw0['Chest']@self.N['Chest'].inverted()
  self.handlocal=Vector((0,rig.data.bones['ForeArm.L'].length*.78,0))
  self.approved_anchor=approved['ForeArm.L']@self.handlocal
  self.anchor_to_carrier=approved['WeaponCarrier'].inverted()@self.approved_anchor
  self.rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
  self.footverts={n:[v.co.copy() for v in mesh.data.vertices if any(g.group==mesh.vertex_groups[n].index and g.weight>.99 for g in v.groups)] for n in ['Leg.L','Leg.R']}
  self.maximum={'left_orientation_projection_degrees':0.,'left_shoulder_projection_m':0.,'leg_floor_lift_m':0.,'head_clearance_lift_m':0.,'holding_clearance_drop_m':0.,'left_weapon_collision_orientation_degrees':0.,'minimum_left_source_orientation_fraction':1.}
  mesh.data.calc_loop_triangles();self.armgeometry={}
  for name in ['UpperArm.L','ForeArm.L']:
   group=mesh.vertex_groups[name].index;ids={v.index for v in mesh.data.vertices if any(g.group==group and g.weight>.99 for g in v.groups)}
   self.armgeometry[name]=([v.co.copy() for v in mesh.data.vertices],[tuple(t.vertices) for t in mesh.data.loop_triangles if set(t.vertices)<=ids])
 def clear_weapon(self,upper,forearm,weapon):
  D=weapon@self.B['WeaponCarrier'].inverted();trees=[]
  for verts,tris in self.weapons:trees.append(BVHTree.FromPolygons([D@v for v in verts],tris,all_triangles=True))
  for n,M in [('UpperArm.L',upper),('ForeArm.L',forearm)]:
   verts,tris=self.armgeometry[n];D=M@self.rest[n].inverted();tree=BVHTree.FromPolygons([D@v for v in verts],tris,all_triangles=True)
   if any(tree.overlap(w) for w in trees):return False
  return True
 def desired(self,channels):
  M=self.mapper.desired(channels,entity_head=True)
  raw={n:m.copy() for n,m in M.items()}
  for side in ['R','L']:
   n='UpperArm.'+side;D=raw[n]@self.raw0[n].inverted()
   for n in ['UpperArm.'+side,'ForeArm.'+side]:M[n]=D@self.body0@self.B[n]
   if side=='R':M['WeaponCarrier']=D@self.body0@self.B['WeaponCarrier']
  # Rifle/right hand follows source right arm exactly after static grip calibration.
  # Left uses closest swing that satisfies one rigid arm + the existing support anchor.
  target=M['WeaponCarrier']@self.anchor_to_carrier
  source=M['UpperArm.L'].copy();F=M['ForeArm.L'].copy();current=F@self.handlocal
  direction=(target-source.translation).normalized();length=(current-source.translation).length
  swing=(current-source.translation).normalized().rotation_difference(direction)
  orientation=swing.to_matrix()@source.to_3x3()
  shoulder=target-direction*length
  M['UpperArm.L']=orientation.to_4x4();M['UpperArm.L'].translation=shoulder
  M['ForeArm.L']=M['UpperArm.L']@source.inverted()@F
  self.maximum['left_orientation_projection_degrees']=max(self.maximum['left_orientation_projection_degrees'],math.degrees(swing.angle))
  self.maximum['left_shoulder_projection_m']=max(self.maximum['left_shoulder_projection_m'],(shoulder-source.translation).length)
  # Keep as much independent source left-arm orientation as the long rifle's
  # actual magazine/handguard allows, rather than letting the solid hand cut it.
  projected=M['UpperArm.L'].to_quaternion();fixed=(M['WeaponCarrier']@self.B['WeaponCarrier'].inverted()@self.B['UpperArm.L']).to_quaternion()
  upper_to_fore=self.B['UpperArm.L'].inverted()@self.B['ForeArm.L'];anchor_local=upper_to_fore@self.handlocal
  def pose(fraction):
   q=fixed.slerp(projected,fraction);U=q.to_matrix().to_4x4();U.translation=target-q@anchor_local
   return U,U@upper_to_fore
  if not self.clear_weapon(M['UpperArm.L'],M['ForeArm.L'],M['WeaponCarrier']):
   lo,hi=0.,1.;U,F=pose(0.);assert self.clear_weapon(U,F,M['WeaponCarrier'])
   for i in range(12):
    mid=(lo+hi)/2;U,F=pose(mid)
    if self.clear_weapon(U,F,M['WeaponCarrier']):lo=mid
    else:hi=mid
   U,F=pose(max(0,lo-.001));M['UpperArm.L']=U;M['ForeArm.L']=F
   self.maximum['minimum_left_source_orientation_fraction']=min(self.maximum['minimum_left_source_orientation_fraction'],lo)
   self.maximum['left_weapon_collision_orientation_degrees']=max(self.maximum['left_weapon_collision_orientation_degrees'],math.degrees(projected.rotation_difference(U.to_quaternion()).angle))
  # Our square head and shirt meet at a different pivot than the source model.
  # One fixed25mm head/Neck clearance preserves ALL source head timing/rotation.
  for n in ['Head','Neck']:M[n]=Matrix.Translation((0,0,.025))@M[n]
  self.maximum['head_clearance_lift_m']=.025
  # Preserve literal leg rotations and horizontal translations; only lift rigid
  # sole corners that would penetrate the fixed floor because of our boot geometry.
  for n in ['Leg.L','Leg.R']:
   z=min((M[n]@self.rest[n].inverted()@v).z for v in self.footverts[n]);lift=max(0.,.0004-z)
   M[n]=Matrix.Translation((0,0,lift))@M[n]
   self.maximum['leg_floor_lift_m']=max(self.maximum['leg_floor_lift_m'],lift)
  return M,raw
