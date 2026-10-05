import bpy,time
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/animation')
def render_batch(action,start,end):
    scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig']
    rig.animation_data.action=None
    for p in rig.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
    rig.animation_data.action=bpy.data.actions[action]
    scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.cycles.samples=16
    folder=OUT/'frames'/action;folder.mkdir(parents=True,exist_ok=True)
    begun=time.monotonic()
    for frame in range(start,end+1):
        scene.frame_set(frame);scene.render.filepath=str(folder/f'{frame:04d}.png');bpy.ops.render.render(write_still=True)
    return {'action':action,'frames':[start,end],'seconds':round(time.monotonic()-begun,2),'folder':str(folder)}
