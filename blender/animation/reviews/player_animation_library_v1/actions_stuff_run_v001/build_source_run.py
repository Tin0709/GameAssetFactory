"""Build ONE research Action from verified source channels, no handcrafted motion."""
import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from source_motion import *
from retarget_source import Retarget
state=json.loads((HERE/'preservation_before.json').read_text());ROOT=Path(state['project'])
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as lib
NAME=state['action'];RIG='ASR_Player_Rig_v001';MESH='ASR_Player_Mesh_v001';SCENE='ASR_Running_Review_v001'
assert NAME not in bpy.data.actions and SCENE not in bpy.data.scenes
before={a.name:lib.action_signature(a)for a in bpy.data.actions}
neutral=json.loads(bpy.data.texts['GAF_Neutral_Pose.json'].as_string())
old=bpy.context.scene;sc=bpy.data.scenes.new(SCENE);sc.world=old.world
rig=bpy.data.objects['Showcase_Player_Rig'].copy();rig.name=RIG;rig.animation_data_clear();sc.collection.objects.link(rig)
mesh=bpy.data.objects['Showcase_Player_Mesh'].copy();mesh.name=MESH;mesh.parent=rig;sc.collection.objects.link(mesh)
for m in mesh.modifiers:
 if m.type=='ARMATURE':m.object=rig
rig.hide_render=False;mesh.hide_render=False;rig.hide_set(False);mesh.hide_set(False)
for ob in old.objects:
 if ob.type in ['CAMERA','LIGHT']:sc.collection.objects.link(ob)
floor=bpy.data.objects['Showcase_FixedFloor'].copy();floor.name='ASR_FixedFloor';sc.collection.objects.link(floor)
sc.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.context.window.scene=sc
for b in rig.pose.bones:
 for k,v in neutral[b.name].items():setattr(b,k,v)
bpy.context.view_layer.update();mapper=Retarget(rig)
breaks=source_break_times();grid=[i/480 for i in range(int(DURATION*480)+1)]
# Original breakpoints have priority over grid points inside Blender's key merge threshold.
times=sorted(set(breaks)|{t for t in grid if min(abs(t-k)for k in breaks)*FPS>.0101})
rows=[];forearm_error=0;scale_limits={n:[float('inf'),float('-inf')]for n in mapper.base}
for t in times:
 d=mapper.desired(t);row={}
 for b in rig.data.bones:
  kwargs={}if not b.parent else{'parent_matrix':d[b.parent.name],'parent_matrix_local':b.parent.matrix_local}
  basis=b.convert_local_to_pose(d[b.name],b.matrix_local,invert=True,**kwargs)
  if b.name.startswith('ForeArm.'):
   forearm_error=max(forearm_error,max(abs(basis[i][j]-Matrix.Identity(4)[i][j])for i in range(4)for j in range(4)))
   basis=Matrix.Identity(4)
  row[b.name]=basis
  ss=basis.to_scale();scale_limits[b.name][0]=min(scale_limits[b.name][0],min(ss));scale_limits[b.name][1]=max(scale_limits[b.name][1],max(ss))
 rows.append(row)
assert forearm_error<2e-6
a=bpy.data.actions.new(NAME);slot=a.slots.new(id_type='OBJECT',name=rig.name)
bag=a.layers.new('Verified source running + steady runtime layers').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
for bone in rig.pose.bones:
 rotation='rotation_quaternion'if bone.rotation_mode=='QUATERNION'else'rotation_euler';previous=None
 data={'location':[],rotation:[],'scale':[]}
 for row in rows:
  loc,q,scale=row[bone.name].decompose()
  if rotation=='rotation_quaternion':
   if previous is not None and q.dot(previous)<0:q.negate()
   val=q;previous=q.copy()
  else:
   val=q.to_euler(bone.rotation_mode,previous)if previous is not None else q.to_euler(bone.rotation_mode);previous=val.copy()
  data['location'].append(list(loc));data[rotation].append(list(val))
  # Preserve the verified source leg-length channel. Numerical unit axes are
  # set exactly to 1; no source scale pulse is discarded.
  ss=[1.,1.,1.]
  if bone.name in ['Leg.L','Leg.R']:ss[1]=scale[1]
  else:assert max(abs(x-1)for x in scale)<2e-6
  data['scale'].append(ss)
 for prop,values in data.items():
  for axis in range(len(values[0])):
   curve=bag.fcurves.new(bone.path_from_id(prop),index=axis);curve.keyframe_points.add(len(times))
   curve.keyframe_points.foreach_set('co',[x for t,v in zip(times,values)for x in (1+t*FPS,v[axis])])
   for k in curve.keyframe_points:k.interpolation='LINEAR'
   curve.update()
   assert len(curve.keyframe_points)==len(times),'Original source breakpoint was merged'
a.use_fake_user=True;a['research_only']=True;a['production_eligible']=False;a['source_animation']='animation.oreville_ans.fngydr';a['source_pack_sha256']=state['pack_sha256']
rig.animation_data_create();rig.animation_data.action=a;rig.animation_data.action_slot=slot
sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=12;sc.cycles.use_denoising=True
sc.render.resolution_x=sc.render.resolution_y=640;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG'
sc.render.fps=FPS;sc.render.fps_base=1;sc.frame_start=1;sc.frame_end=int(DURATION*FPS);sc.frame_set(1)
sc['research_only']=True;sc['full_composite_seamless']=False;sc['source_profile']=json.dumps(PROFILE)
# Native geometry determines display alignment only. Keep source trajectories untouched.
ids=[v.index for v in mesh.data.vertices if any(g.group in [mesh.vertex_groups['Leg.L'].index,mesh.vertex_groups['Leg.R'].index]and g.weight>.99 for g in v.groups)]
rest={b.name:b.matrix_local.copy()for b in rig.data.bones};minimum=10.
groups={side:[v.index for v in mesh.data.vertices if any(g.group==mesh.vertex_groups['Leg.'+side].index and g.weight>.99 for g in v.groups)]for side in ['L','R']}
for i in range(2881):
 t=i/480;d=mapper.desired(t)
 for side in ['L','R']:
  deform=d['Leg.'+side]@rest['Leg.'+side].inverted()
  minimum=min(minimum,min((deform@mesh.data.vertices[j].co).z for j in groups[side]))
floor.location.z=minimum-.0004
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
expected=[{'time_s':t,'frame':1+FPS*t,'matrices':{n:[list(r)for r in m]for n,m in mapper.desired(t).items()}}for t in sorted(set([i/120 for i in range(721)]+breaks))]
(HERE/'expected_matrices.json').write_text(json.dumps(expected))
manifest={'action':NAME,'scene':SCENE,'source_rig':RIG,'source_mesh':MESH,'status':'pending','research_only':True,'production_eligible':False,
 'source_animation':'animation.oreville_ans.fngydr','source_pack_sha256':state['pack_sha256'],'profile':PROFILE,
 'start':1,'end':180,'endpoint_sample':181,'fps':FPS,'duration_s':DURATION,'core_period_s':1/RATE,'seamless_loop':False,
 'preview_floor_z_m':floor.location.z,'source_model_unit_m':mapper.unit,'bake_samples':len(times),'original_breakpoints':len(breaks),
 'scale_limits':scale_limits,'rig_sha256':lib.rest_signature(rig.data),'action_sha256':lib.action_signature(a),'previous_action_signatures':before,
 'rotation_convention':'Explicit Rz(rz) Ry(-ry) Rx(-rx), C-conjugated; Three.js ZYX / Blender XYZ',
 'head_convention':'Entity-relative head rotation with parent-translated pivot; native parent rotation compensated',
 'research_scale_channels':{s:{'axis':1,'min':1.0,'max':1.070002}for s in ['Leg.L','Leg.R']}}
assert all(lib.action_signature(bpy.data.actions[n])==h for n,h in before.items())
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.context.preferences.filepaths.save_version=0
dest=HERE/'run_actions_stuff_review.blend';bpy.ops.wm.save_as_mainfile(filepath=str(dest),relative_remap=False,compress=True)
manifest['source_sha256']=hashlib.sha256(dest.read_bytes()).hexdigest();(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('SOURCE_RUN_BUILT',NAME,len(times),'scale',scale_limits['Leg.L'],'floor',floor.location.z,flush=True)
