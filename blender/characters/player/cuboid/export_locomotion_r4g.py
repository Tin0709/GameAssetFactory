"""Run in background Blender. Export copies only; never save the source file."""
import bpy, sys, json, hashlib
from pathlib import Path
from mathutils import Matrix
BASE = Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
from turning_r2_common import curves, digest, bone_signature, geometry
DEV = BASE/'player_locomotion_turning_v2_study.blend'
OUT = BASE/'export/locomotion_r4g'; OUT.mkdir(parents=True,exist_ok=True)
assert Path(bpy.data.filepath) == DEV
protected = {a.name:digest(a) for a in bpy.data.actions}
file_hash = hashlib.sha256(DEV.read_bytes()).hexdigest()
rig,mesh = bpy.data.objects['Player_Cuboid_Rig'],bpy.data.objects['Player_Cuboid_Base']
rest = bone_signature(rig); geo = geometry()
sole_points={}
for name in ['Leg.L','Leg.R']:
    group=mesh.vertex_groups[name].index
    vertices=[v.co for v in mesh.data.vertices if any(g.group==group and g.weight>.999 for g in v.groups)]
    minimum=min(v.z for v in vertices)
    sole_points[name]=[list(rig.data.bones[name].matrix_local.inverted()@v) for v in vertices if abs(v.z-minimum)<1e-5]
(OUT/'sole_points.json').write_text(json.dumps(sole_points))
source_scene = next(s for s in bpy.data.scenes if rig.name in s.objects)
rig.name='SOURCE_Player_Cuboid_Rig';mesh.name='SOURCE_Player_Cuboid_Base'
names = [('Walk_ReferenceStudy_V2','Walk'),('Walk_TurnLeft_Reference_V2','WalkTurnLeft'),('Walk_TurnRight_Reference_V2','WalkTurnRight'),('Sprint_ReferenceStudy_V2','Sprint'),('Sprint_TurnLeft_Reference_V2','SprintTurnLeft'),('Sprint_TurnRight_Reference_V2','SprintTurnRight')]
records={}; copies=set()
for src,name in names:
    a = bpy.data.actions[src]; start,end=map(float,a.frame_range)
    period = 16 if name.startswith('Walk') else 13
    assert start==1 and abs(end-start-period)<1e-6,(src,start,end)
    bones=sorted({c.data_path.split('"')[1] for c in curves(a)})
    assert not any(c.data_path.endswith('scale') for c in curves(a))
    bpy.context.window.scene=source_scene;rig.animation_data_create();rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
    samples=[]
    for step in range(period*8+1):
        for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
        f=1+step/8;source_scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        samples.append({'time':step/192,'bones':{n:[list(row) for row in rig.pose.bones[n].matrix] for n in bones}})
    clean=a.copy();clean.name=name;clean.use_fake_user=True;copies.add(clean)
    scene=bpy.data.scenes.new('R4G_EXPORT');scene.render.fps=192;scene.frame_start=1;scene.frame_end=period*8+1
    r=rig.copy();r.data=rig.data.copy();r.name='Player_Cuboid_Rig';r.animation_data_clear();scene.collection.objects.link(r)
    m=mesh.copy();m.data=mesh.data.copy();m.name='Player_Cuboid_Base';m.animation_data_clear();m.parent=r;scene.collection.objects.link(m)
    for mod in m.modifiers:
        if mod.type=='ARMATURE':mod.object=r
    sampled=clean.copy();sampled.use_fake_user=False
    for c in curves(sampled):
        for k in c.keyframe_points:
            k.co.x=1+(k.co.x-1)*8;k.handle_left.x=1+(k.handle_left.x-1)*8;k.handle_right.x=1+(k.handle_right.x-1)*8
        c.update()
    r.animation_data_create();r.animation_data.action=sampled;r.animation_data.action_slot=sampled.slots[0]
    r.hide_viewport=False;m.hide_viewport=False;r.hide_render=False;m.hide_render=False
    bpy.context.window.scene=scene
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    scene.frame_set(1);r.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=r
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'_raw.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_step=1,export_def_bones=False,export_anim_slide_to_zero=True,export_cameras=False,export_lights=False)
    records[name]={'source':src,'duration':period/24,'bones':bones,'samples':samples}
    bpy.context.window.scene=source_scene;bpy.data.objects.remove(m,do_unlink=True);bpy.data.objects.remove(r,do_unlink=True);bpy.data.scenes.remove(scene)
bpy.data.libraries.write(str(OUT/'locomotion_export_copies.blend'),copies,fake_user=True)
assert all(digest(bpy.data.actions[n])==h for n,h in protected.items())
assert bone_signature(rig)==rest and geometry()[mesh.name]==geo['Player_Cuboid_Base']
assert hashlib.sha256(DEV.read_bytes()).hexdigest()==file_hash
(OUT/'source_samples.json').write_text(json.dumps(records))
(OUT/'protection.json').write_text(json.dumps({'source_file_sha256':file_hash,'source_unchanged':True,'all_source_actions':protected,'rig_rest_hierarchy_unchanged':True,'mesh_weights_unchanged':True},indent=2))
print('R4G_EXPORT_COMPLETE',flush=True)
