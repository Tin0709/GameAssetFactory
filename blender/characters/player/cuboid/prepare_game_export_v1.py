import bpy,ast,json,hashlib,math
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
TEST=BASE/'blocky_character_mixamo_test.blend'; COPY=BASE/'player_cuboid_game_export_v1.blend'
OUT=BASE/'export'; GLB=OUT/'player_cuboid_animated_v1.glb'
assert Path(bpy.data.filepath)==TEST
assert not COPY.exists() and not GLB.exists(), 'Do not overwrite an existing export'
protected={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [TEST,BASE/'player_cuboid_v6.blend']}
t=ast.parse((BASE/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in {'vv','mm','fcurves','action_signature','object_signature'}],type_ignores=[]),'helpers','exec'))
scene=bpy.context.scene; rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
assert mesh.parent==rig and not rig.parent
assert all(abs(o.matrix_world[i][j]-(1 if i==j else 0))<1e-7 for o in [mesh,rig] for i in range(4) for j in range(4))
geometry=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
def activate(a):
 rig.animation_data.action=a
 if a.slots:rig.animation_data.action_slot=a.slots[0]
 for p in rig.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
def sample(f):
 scene.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update()
 dg=bpy.context.evaluated_depsgraph_get();ev=mesh.evaluated_get(dg);me=ev.to_mesh()
 verts=[vv(ev.matrix_world@v.co) for v in me.vertices];ev.to_mesh_clear()
 return dict(vertices=verts,root=mm(rig.matrix_world@rig.pose.bones['Root'].matrix),hips=vv((rig.matrix_world@rig.pose.bones['Hips'].matrix).translation))
sources={'Idle':'Player_Idle','Run':'Player_Run_Blocky_V7_Final'};baseline={};actions={}
for name,source in sources.items():
 a=bpy.data.actions[source];activate(a);lo,hi=map(float,a.frame_range)
 assert not any(c.data_path.endswith('.scale') or not c.data_path.startswith('pose.bones[') for c in fcurves(a))
 samples=[dict(frame=lo+i/4,**sample(lo+i/4)) for i in range(round((hi-lo)*4)+1)]
 assert max(abs(x-y) for x,y in zip(samples[0]['hips'],samples[-1]['hips']))<1e-6
 assert max(abs(samples[0]['root'][i][j]-s['root'][i][j]) for s in samples for i in range(4) for j in range(4))<1e-6
 assert max(abs(x-y) for p,q in zip(samples[0]['vertices'],samples[-1]['vertices']) for x,y in zip(p,q))<1e-6
 baseline[name]=dict(range=[lo,hi],duration=(hi-lo)/24,samples=samples)
 c=a.copy();c.name=name;c.use_fake_user=True;c.use_frame_range=True;c.frame_start=lo;c.frame_end=hi
 before=action_signature(a);after=action_signature(c);before.pop('name');after.pop('name');assert before==after
 actions[name]=c
# Change filepath before any cleanup. Every change below affects only the export copy.
bpy.ops.wm.save_as_mainfile(filepath=str(COPY),check_existing=False)
assert Path(bpy.data.filepath)==COPY
activate(actions['Run'])
for o in list(bpy.data.objects):
 if o not in [rig,mesh]:bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):
 if a not in actions.values():bpy.data.actions.remove(a,do_unlink=True)
for text in list(bpy.data.texts):bpy.data.texts.remove(text)
for blocks in [bpy.data.armatures,bpy.data.meshes,bpy.data.cameras,bpy.data.lights]:
 for d in list(blocks):
  if d.users==0:blocks.remove(d)
assert set(a.name for a in bpy.data.actions)=={'Idle','Run'}
# Explicit neutral values prevent residual pose state when switching clips. These
# export-only constants do not replace any authored curve or animate scale/Root.
neutral_fixes={}
for a in actions.values():
 bag=a.layers[0].strips[0].channelbags[0];existing={(c.data_path,c.array_index) for c in bag.fcurves};added=[]
 for n in rig.pose.bones.keys():
  if n=='Root':continue
  for prop in ['location','rotation_euler']:
   path=f'pose.bones["{n}"].{prop}'
   for axis in range(3):
    if (path,axis) in existing:continue
    c=bag.fcurves.new(path,index=axis)
    for f in a.frame_range:c.keyframe_points.insert(f,0).interpolation='LINEAR'
    added.append((path,axis))
 neutral_fixes[a.name]=added
scene.camera=None;scene.frame_set(1);scene.frame_start=1;scene.frame_end=49
scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for o in [rig,mesh]:o.hide_set(False);o.hide_render=False;o.select_set(True)
bpy.context.view_layer.objects.active=rig
assert geometry==object_signature(mesh)
s=object_signature(rig);s.pop('pose');s.pop('action');assert structure==s
OUT.mkdir(exist_ok=True)
# Pack the existing textures without changing pixel data or touching their source files.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(COPY),check_existing=False)
# Export samples at 96 Hz using a transient time-coordinate conversion. Seconds and
# authored 24-FPS motion remain identical; this transient state is never saved.
for a in actions.values():
 for c in fcurves(a):
  for k in c.keyframe_points:
   co=k.co.copy();left=k.handle_left.copy();right=k.handle_right.copy()
   k.co.x=1+(co.x-1)*4;k.handle_left.x=1+(left.x-1)*4;k.handle_right.x=1+(right.x-1)*4
  c.update()
 a.frame_end=1+(baseline[a.name]['range'][1]-1)*4
scene.render.fps=96
bpy.ops.export_scene.gltf(filepath=str(GLB),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,export_anim_slide_to_zero=True,export_frame_range=False,export_force_sampling=True,export_frame_step=1,export_skins=True,export_rest_position_armature=True,export_armature_object_remove=False,export_optimize_animation_size=True,export_optimize_animation_keep_anim_armature=False,export_optimize_animation_keep_anim_object=False,export_morph_animation=False,export_cameras=False,export_lights=False,export_extras=False)
assert protected=={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in protected}
manifest=dict(export_blend=str(COPY),glb=str(GLB),mesh=mesh.name,armature=rig.name,clips={n:dict(range=b['range'],duration=b['duration']) for n,b in baseline.items()},authoring_fps=24,export_sampling_hz=96,blender_forward='-Y',gltf_forward='+Z',gltf_up='+Y',transforms_changed=False,mesh_transform=dict(location=vv(mesh.location),rotation_euler=vv(mesh.rotation_euler),scale=vv(mesh.scale)),armature_transform=dict(location=vv(rig.location),rotation_euler=vv(rig.rotation_euler),scale=vv(rig.scale)),protected_hashes=protected,rest_vertices=[vv(v.co) for v in mesh.data.vertices],baseline=baseline)
manifest['technical_export_fix_constant_neutral_channels']=neutral_fixes
(OUT/'player_cuboid_export_validation_input.json').write_text(json.dumps(manifest),encoding='utf-8')
print('EXPORT_CREATED='+json.dumps({k:v for k,v in manifest.items() if k not in ['baseline','rest_vertices']}),flush=True)
