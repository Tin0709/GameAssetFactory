"""Refine the exact approved visual base; copy all unaffected curves verbatim."""
import bpy,sys,json,math,hashlib,argparse
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());A=Path(__file__).resolve().parent;O=A.parent
sys.path.insert(0,str(A));sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
from support_motion import sample,ARM_DROP_M
BASE='Rifle_Ready_Idle_ActionsStyle_v003';NAME='Rifle_Ready_Idle_ActionsStyle_v004'
source=ROOT/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v003/rifle_ready_idle_actionsstyle_v003.blend'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='b23fb544ee9ab74d325874cbea6b8d189cd582dd5bcee83fabef7ff769f645d1'
assert Path(bpy.data.filepath)==source
if (O/'rifle_ready_idle_actionsstyle_v004.blend').exists() and '--rebuild-pending' not in sys.argv:raise RuntimeError('Pending source exists; explicit --rebuild-pending required')
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());assert not any(e['action']==NAME and e['status']=='approved' for e in manifest['animations'])
rig=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];scene=bpy.context.scene;base=bpy.data.actions[BASE]
assert ui.action_signature(base)=='d803fbf8f04043c57e0eea3c9d98a6360af8be929b629d4a73eb4a629f8470ce'
before={a.name:ui.action_signature(a) for a in bpy.data.actions};rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
rig.animation_data.action=base;rig.animation_data.action_slot=base.slots[0];scene['gaf_library_last_action']=BASE;scene.frame_set(1);bpy.context.view_layer.update()
B={b.name:b.matrix.copy() for b in rig.pose.bones};wc0=B['WeaponCarrier'];weapons=[]
for name in ['Rifle_V2_Body','Rifle_V2_Magazine']:
 obj=bpy.data.objects[name];obj.data.calc_loop_triangles();verts=[obj.matrix_world@v.co for v in obj.data.vertices];tris=[tuple(t.vertices) for t in obj.data.loop_triangles];weapons.append((verts,tris))
# Use both actual weapon surfaces toward the support palm, including the
# magazine. A single far arm-vertex normal can point into the magazine.
mesh.data.calc_loop_triangles();group=mesh.vertex_groups['ForeArm.L'].index
ids={v.index for v in mesh.data.vertices if any(g.group==group and g.weight>.99 for g in v.groups)}
vs=[mesh.matrix_world@(B['ForeArm.L']@rest['ForeArm.L'].inverted()@v.co) for v in mesh.data.vertices]
tree=BVHTree.FromPolygons(vs,[tuple(t.vertices) for t in mesh.data.loop_triangles if set(t.vertices)<=ids],all_triangles=True)
normals=[]
for wvs,wts in weapons:
 rows=[(tree.find_nearest(p)[3],p,tree.find_nearest(p)[0]) for p in wvs]
 distance,p,v=min(rows,key=lambda row:row[0]);normals.append((v-p).normalized())
normal_local=(wc0.to_3x3().inverted()@sum(normals,Vector((0,0,0)))).normalized()
along_local=Vector((0,1,0));along_local=(along_local-normal_local*along_local.dot(normal_local)).normalized()
handlocal=Vector((0,rig.data.bones['ForeArm.L'].length*.78,0))
mesh.data.calc_loop_triangles();left_geometry={}
for n in ['UpperArm.L','ForeArm.L']:
 group=mesh.vertex_groups[n].index;ids={v.index for v in mesh.data.vertices if any(g.group==group and g.weight>.99 for g in v.groups)}
 left_geometry[n]=([v.co.copy() for v in mesh.data.vertices],[tuple(t.vertices) for t in mesh.data.loop_triangles if set(t.vertices)<=ids])
def weapon_clear(M):
 D=M['WeaponCarrier']@wc0.inverted();trees=[BVHTree.FromPolygons([D@v for v in vs],ts,all_triangles=True) for vs,ts in weapons]
 for n in left_geometry:
  vs,ts=left_geometry[n];D=M[n]@rest[n].inverted();tree=BVHTree.FromPolygons([D@v for v in vs],ts,all_triangles=True)
  if any(tree.overlap(w) for w in trees):return False
 return True
frames=sorted({float(k.co.x) for c in ui.curves(base) for k in c.keyframe_points});values={};max_offset=0.;max_shoulder=0.;trimmed=0;minimum_fraction=1.;min_drop=10.;max_drop=-10.
for f in frames:
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();old={b.name:b.matrix.copy() for b in rig.pose.bones};m=sample((f-1)/30)
 lower=Matrix.Translation((0,0,-ARM_DROP_M));lowered={n:(lower@M if n in ['UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L','WeaponCarrier'] else M.copy()) for n,M in old.items()}
 anchor=lowered['ForeArm.L']@handlocal;wc=lowered['WeaponCarrier'];rotation=wc.to_3x3()
 offset=rotation@(normal_local*m['pressure_release_m']+along_local*m['along_rifle_m']);axis=rotation.col[2].normalized()
 def trial(fraction):
  M={n:x.copy() for n,x in lowered.items()};D=Matrix.Translation(offset*fraction)@Matrix.Translation(anchor)@Matrix.Rotation(math.radians(m['shoulder_angle_degrees']*fraction),4,axis)@Matrix.Translation(-anchor)
  for n in ['UpperArm.L','ForeArm.L']:M[n]=D@lowered[n]
  return M
 M=trial(1.);fraction=1.
 if not weapon_clear(M):
  assert weapon_clear(lowered),'Base support geometry unexpectedly intersecting weapon'
  lo,hi=0.,1.
  for i in range(12):
   mid=(lo+hi)/2
   if weapon_clear(trial(mid)):lo=mid
   else:hi=mid
  fraction=max(0.,lo-.002);M=trial(fraction);trimmed+=1;minimum_fraction=min(minimum_fraction,fraction)
 max_offset=max(max_offset,(M['ForeArm.L']@handlocal-anchor).length);max_shoulder=max(max_shoulder,(M['UpperArm.L'].translation-lowered['UpperArm.L'].translation).length)
 for n in ['UpperArm.R','ForeArm.R','WeaponCarrier']:
  drop=old[n].translation.z-M[n].translation.z;min_drop=min(min_drop,drop);max_drop=max(max_drop,drop)
 row={}
 for n in ['UpperArm.L','UpperArm.R','WeaponCarrier']:
  b=rig.data.bones[n];args={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':rest[b.parent.name]}
  basis=b.convert_local_to_pose(M[n],rest[n],invert=True,**args);pos,q,scale=basis.decompose();oldq=rig.pose.bones[n].rotation_quaternion
  if q.dot(oldq)<0:q.negate()
  row[n]={'location':list(pos),'rotation_quaternion':list(q)}
 values[f]=row
new=base.copy();new.name=NAME;new.use_fake_user=True;changed=[]
for c in ui.curves(new):
 n=c.data_path.split('"')[1];prop=c.data_path.split('.')[-1]
 if (n=='UpperArm.L' and prop in ['location','rotation_quaternion']) or (n in ['UpperArm.R','WeaponCarrier'] and prop=='location'):
  array=[values[float(k.co.x)][n][prop][c.array_index] for k in c.keyframe_points]
  # Retain inherited carrier curves exactly if the arm hierarchy already carries
  # the entire18mm drop; this keeps an unnecessary re-bake out of the candidate.
  if max(abs(y-k.co.y) for y,k in zip(array,c.keyframe_points))>5e-7:
   c.keyframe_points.foreach_set('co',[v for k,y in zip(c.keyframe_points,array) for v in [k.co.x,y]]);c.update();changed.append([n,prop,c.array_index])
rig.animation_data.action=new;rig.animation_data.action_slot=new.slots[0];scene['gaf_library_last_action']=NAME;scene.frame_start=1;scene.frame_end=324;scene.render.fps=30;scene.frame_set(1);scene.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(scene,{'preview_prop':'rifle_stylized_v2'})
new['refinement_base']=BASE;new['refinement_note']='18mm whole holding-set drop; restrained delayed source-clock support micro motion. Core source curves unchanged.'
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
source4=O/'rifle_ready_idle_actionsstyle_v004.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source4),compress=True,check_existing=False)
e=dict(next(e for e in manifest['animations'] if e['action']==BASE));e.update({'action':NAME,'source':source4.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source4.read_bytes()).hexdigest(),'action_sha256':ui.action_signature(new),'status':'pending','approval_note':'Refinement of artistically approved v003 visual base.18mm lower holding set and subtle support-side source-clock life; Pending Blender review only.','refinement_base':BASE,'arm_drop_m':ARM_DROP_M,'left_support_motion':'0.4..1.6mm pressure release plus±0.8mm tangent,±0.15degree whole straight arm overlap; clocks0.9/1.8s; collision bounded','original_custom_animation':False,'research_only':True,'production_eligible':False})
ui.validate_action(new,e,rig);(O/'entry.json').write_text(json.dumps(e,indent=2))
report={'passed':True,'base_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'base_action_sha256':ui.action_signature(base),'candidate_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'changed_curves':changed,'all_other_curves_copied_exactly':True,'frames':len(frames),'duration_s':10.8,'arm_drop_range_m':[min_drop,max_drop],'maximum_left_anchor_motion_m':max_offset,'maximum_left_shoulder_motion_m':max_shoulder,'collision_trimmed_samples':trimmed,'minimum_motion_fraction':minimum_fraction,'support_normal_carrier_local':list(normal_local),'support_tangent_carrier_local':list(along_local),'source_clock_support_periods_s':[.9,1.8],'source_clock_phase_lags_degrees':[30,20,50],'source_file_unchanged':True}
(O/'build_validation.json').write_text(json.dumps(report,indent=2));print('V004_REFINED',json.dumps(report),flush=True)
