"""Normal-time E1 comparison renders. Run cadence is already baked at 1.60."""
import bpy, sys, math
from pathlib import Path
from mathutils import Matrix
BASE=Path(__file__).resolve().parent
out=BASE/'ready_e1_review';out.mkdir(exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
layer=args[0] if args else 'Idle'
mode=args[1] if len(args)>1 else 'stills'
scene=bpy.data.scenes['E1_'+layer+'_Phase0_AB']
bpy.context.window.scene=scene
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
q=(D@Matrix.Rotation(math.radians(36.86989764584402),3,'Y')@Matrix.Rotation(math.radians(-36.31588642394517),3,'X')).to_quaternion()
for o in scene.objects:
    if o.type=='CAMERA':
        o.rotation_euler=q.to_euler()
        o.location=scene.camera.location
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=960;scene.render.resolution_y=576;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB'
scene.render.film_transparent=False
scene.render.fps=24;scene.render.fps_base=1
scene.camera=next(o for o in scene.objects if o.type=='CAMERA' and o.name.endswith('Detail'))
scene.render.filepath=str(out/(layer+'_detail_'))
if mode=='stills':
    for f in [1,7,12,19,26]:
        scene.frame_set(f);scene.render.filepath=str(out/(layer+'_detail_%03d.png'%f))
        bpy.ops.render.render(write_still=True)
    scene.camera=next(o for o in scene.objects if o.type=='CAMERA' and o.name.endswith('GameplayScale'))
    scene.frame_set(12);scene.render.filepath=str(out/(layer+'_gameplay_012.png'))
    bpy.ops.render.render(write_still=True)
else:
    scene.render.filepath=str(out/(layer+'_motion_'))
    bpy.ops.render.render(animation=True)
