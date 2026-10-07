import bpy,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'arm_r8a1_review'
quick='--quick' in sys.argv
for label,scene_name,rig_name,action_name,f in [('A','R8A1_LEGACY','R8A1_Legacy_Rig','LongGunHold_V2',1),('B','R8A1_LEGACY','R8A1_Legacy_Rig','LongGunHold_ReferenceStudy_V1',1),('C','R8A1_AUTHORING','R8A1_RigV2_Author','LongGunHold_RigV2_Study_V1',1),('D','R8A1_AUTHORING','R8A1_RigV2_Author','LongGunAimBias_RigV2_Study_V1',20)]:
 if quick and label!='C':continue
 s=bpy.data.scenes[scene_name];bpy.context.window.scene=s;r=bpy.data.objects[rig_name];a=bpy.data.actions[action_name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for v in (['Front','Side','Gameplay'] if quick else ['Front','Side','Gameplay','Rear','GameplayDistance','CloseGun','GameplayOpposite']):
  s.camera=bpy.data.objects['R8A1_'+v];s.frame_set(f);s.render.filepath=str(OUT/f'{label}_{v}.png');bpy.ops.render.render(write_still=True)
print('R8A1_RENDERED',flush=True)
if not quick:
 for scene_name,filename,rx,ry in [('R8A1_COMPARISON','ABCD_aim_24fps.mp4',1920,900),('R8A1_AUTHORING','aim_close_24fps.mp4',1200,720)]:
  s=bpy.data.scenes[scene_name];bpy.context.window.scene=s
  if scene_name=='R8A1_AUTHORING':s.camera=bpy.data.objects['R8A1_CloseGun']
  s.render.resolution_x=rx;s.render.resolution_y=ry;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/filename)
  bpy.ops.render.render(animation=True)
 print('R8A1_MOTION_RENDERED',flush=True)
