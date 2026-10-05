import bpy,math,json
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];action=bpy.data.actions['Player_Run_Blocky_V1']
rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
for p in rig.pose.bones:p.scale=(1,1,1)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
folder=BASE/'blocky_v1_pass1_review';folder.mkdir(exist_ok=True)
frames=[1,3,5,7,9,11,13,15,17]
for label,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera')]:
    scene.camera=bpy.data.objects[camera]
    for i,frame in enumerate(frames):
        scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))
        scene.render.filepath=str(folder/f'{label}_{i:02d}.png')
        bpy.ops.render.render(write_still=True)
        print('REVIEW_RENDER_COMPLETE',label,frame,flush=True)
(folder/'manifest.json').write_text(json.dumps({'frames':frames,'views':['iso','side'],'action':action.name},indent=2),encoding='utf-8')

