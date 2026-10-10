"""Additive, original 24-frame FK capability test. Run in foreground Blender."""
import bpy, json, math, runpy, shutil, hashlib
from pathlib import Path
from mathutils import Euler, Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
TMP = ROOT / '.validation/expressive_arm_motion_test'
LIB = OUT.parent / 'player_animation_library_v1.blend'
HELPER = runpy.run_path(str(OUT.parent/'jump_dungeons_gif_v004/build_jump.py'))

def build():
    assert Path(bpy.data.filepath).resolve() == LIB.resolve()
    assert bpy.context.mode == 'OBJECT'
    assert 'Expressive_Arm_Motion_Test' not in bpy.data.actions
    TMP.mkdir(parents=True,exist_ok=True)
    backup = TMP/'library_before_test.blend'
    assert not backup.exists()
    shutil.copy2(LIB, TMP/'library_disk_before_test.blend')
    before = HELPER['original_data']()
    (TMP/'original_data.json').write_text(json.dumps(before,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True)
    source_hash = hashlib.sha256(LIB.read_bytes()).hexdigest()
    s = bpy.data.scenes.new('EXPRESSIVE_ARM_MOTION_REVIEW')
    template = bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW']
    s.world = template.world
    s.render.engine='CYCLES'; s.cycles.device='GPU'; s.cycles.samples=16
    s.cycles.use_denoising=True
    s.render.resolution_x=s.render.resolution_y=640
    s.render.resolution_percentage=100
    s.render.fps=30; s.render.fps_base=1
    s.frame_start=1; s.frame_end=24
    s.render.image_settings.file_format='PNG'
    s.render.use_motion_blur=False
    for k in ['view_transform','look','exposure','gamma']:
        setattr(s.view_settings,k,getattr(template.view_settings,k))
    rig=bpy.data.objects['JD1_Player_Rig'].copy()
    rig.data=rig.data.copy();rig.name='EAM_Player_Rig';rig.data.name='EAM_Unmodified_RestRig'
    rig.animation_data_clear();rig.parent=None;rig.matrix_world=Matrix.Identity(4)
    s.collection.objects.link(rig)
    mesh=bpy.data.objects['JD1_Player_Mesh'].copy();mesh.name='EAM_Player_Mesh'
    mesh.parent=rig;s.collection.objects.link(mesh)
    for m in mesh.modifiers:
        if m.type=='ARMATURE':m.object=rig
    idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    for b in rig.pose.bones:
        for k,v in idle[b.name].items():setattr(b,k,v)
    for obj in [rig,mesh]:obj.hide_viewport=obj.hide_render=False
    for suffix in ['FixedFloor','Key','Fill','Rim']:
        o=bpy.data.objects['JD1_'+suffix].copy();o.name='EAM_'+suffix;s.collection.objects.link(o)
    for name,loc in [('FRONT',(0,-7,2.2)),('THREE_QUARTER',(3,-6,3.0))]:
        d=bpy.data.cameras.new('EAM_'+name);d.type='ORTHO';d.ortho_scale=2.6
        o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);o.location=loc
        o.rotation_euler=(Vector((0,0,.94))-o.location).to_track_quat('-Z','Y').to_euler()
    s.camera=bpy.data.objects['EAM_THREE_QUARTER']
    bpy.context.window.scene=s
    action=bpy.data.actions.new('Expressive_Arm_Motion_Test');action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    # Independently timed FK arcs. No shoulder translation, scale, leg or root motion.
    tracks={
      'UpperArm.R':[(1,(0,0,0)),(4,(-22,0,-18)),(7,(-57,0,-44)),(9,(-43,0,-46)),(12,(36,0,-42)),(14,(78,0,-38)),(16,(70,0,-31)),(20,(13,0,-14)),(22,(-4,0,-3)),(24,(0,0,0))],
      'UpperArm.L':[(1,(0,0,0)),(4,(-14,0,9)),(6,(-43,0,23)),(8,(-48,0,29)),(11,(12,0,41)),(13,(59,0,43)),(15,(64,0,38)),(19,(19,0,18)),(22,(-3,0,4)),(24,(0,0,0))],
      'Spine':[(1,(0,0,0)),(7,(-2,1,0)),(11,(2,-1,0)),(14,(3,-2,0)),(19,(1,.5,0)),(24,(0,0,0))],
      'Chest':[(1,(0,0,0)),(6,(-4,3,0)),(9,(-2,2,0)),(13,(5,-4,0)),(16,(4,-2,0)),(20,(-1,1,0)),(24,(0,0,0))],
      'Head':[(1,(0,0,0)),(4,(0,0,0)),(8,(4,-2,0)),(11,(1,-1,0)),(15,(-5,3,0)),(18,(-3,1,0)),(22,(.7,-.5,0)),(24,(0,0,0))]
    }
    for name,keys in tracks.items():
        b=rig.pose.bones[name]
        for f,deg in keys:
            rot=Euler(tuple(math.radians(x) for x in deg),'ZXY' if name.startswith('UpperArm') else 'XYZ')
            if b.rotation_mode=='QUATERNION':b.rotation_quaternion=rot.to_quaternion();prop='rotation_quaternion'
            else:b.rotation_euler=rot;prop='rotation_euler'
            b.keyframe_insert(prop,frame=f,group=name)
    for c in HELPER['curves'](action):
        for k in c.keyframe_points:
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='AUTO_CLAMPED'
    for f,label in [(1,'NEUTRAL'),(7,'BACK SWING'),(14,'FORWARD / OUTWARD'),(24,'SETTLED')]:s.timeline_markers.new(label,frame=f)
    s['purpose']='Original Blender-only FK pose capability test; no production locomotion or export.'
    s.frame_set(14)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
    changes=HELPER['compare_originals'](before);assert not changes,changes
    # Keep pre-existing orphan image copies through Save As / reopen.
    for image in bpy.data.images:
        if image.name in before['images'] and image.users==0:image.use_fake_user=True
    manifest={'action':action.name,'frames':[1,24],'fps':30,'source_library':str(LIB),'source_sha256':source_hash,'backup':str(backup),'old_actions':len(before['actions']),'rig_changes':[],'pose_tracks_degrees':tracks,'mesh_data':mesh.data.name,'scene':s.name,'status':'Blender only; pending human review'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'expressive_arm_motion_review.blend'))
    return manifest

def render(view,start,end):
    s=bpy.data.scenes['EXPRESSIVE_ARM_MOTION_REVIEW'];bpy.context.window.scene=s
    s.camera=bpy.data.objects['EAM_'+view]
    p=OUT/'frames'/view.lower();p.mkdir(parents=True,exist_ok=True)
    for f in range(start,end+1):
        s.frame_set(f);s.render.filepath=str(p/f'{f:03d}.png')
        bpy.ops.render.render(write_still=True,scene=s.name)
    return {'view':view,'start':start,'end':end}
