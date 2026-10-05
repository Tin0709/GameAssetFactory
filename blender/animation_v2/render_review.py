import bpy,sys,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
kind=args[0] if args else 'Player'
bpy.ops.wm.open_mainfile(filepath=str(OUT/('player_review_v2.blend' if kind=='Player' else 'zombie_animation_v2.blend')))
rig=bpy.data.objects[kind+'_Cuboid_Rig']; scene=bpy.context.scene
scene.render.resolution_x=320;scene.render.resolution_y=320;scene.cycles.samples=16
names=[kind+'_Idle',kind+'_Walk']+(['Player_Run'] if kind=='Player' else [])
if kind=='Player':
    names+=['REVIEW_'+w+'_'+mode for w in ['Pistol','M4A1','Shotgun'] for mode in ['WalkLowReady','RunLowReady','Raise','Fire']]
    names+=['REVIEW_Locomotion_Transitions']
if len(args)>1:names=args[1:]
for name in names:
    rig.animation_data.action=None
    for p in rig.pose.bones:p.matrix_basis.identity()
    rig.animation_data.action=bpy.data.actions[name]
    for c in bpy.data.collections:
        if c.name.endswith('_Review'):
            show=name.startswith('REVIEW_'+c.name.split('_')[0]+'_')
            c.hide_render=not show;c.hide_viewport=not show
    count=int(rig.animation_data.action['playback_frames'])
    folder=OUT/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
    for i in range(24):
        f=1+i*count/24
        scene.frame_set(int(f),subframe=f%1)
        scene.render.filepath=str(folder/f'{i:03d}.png')
        bpy.ops.render.render(write_still=True)
    if 'Idle' not in name:
        scene.camera.location=(4,-.15,1.7)
        scene.camera.rotation_euler=(Vector((0,-.1,.90))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        for i in range(8):
            f=1+i*count/8;scene.frame_set(int(f),subframe=f%1)
            scene.render.filepath=str(folder/f'side_{i:02d}.png');bpy.ops.render.render(write_still=True)
        scene.camera.location=(-3.4,-5,3)
        scene.camera.rotation_euler=(Vector((0,-.1,.92))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
print('REVIEW_RENDER_SUCCESS',kind)
