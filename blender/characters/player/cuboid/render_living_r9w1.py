"""Actual Blender frames, A/B previews, and close inspection. No synthetic evidence."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w1_review'
quick='--quick' in sys.argv
s=bpy.data.scenes['R9W1_AUTHORING'];bpy.context.window.scene=s;r=bpy.data.objects['R9W1_Author_Rig']
def assign(a):
 r.animation_data.action=bpy.data.actions[a];r.animation_data.action_slot=r.animation_data.action.slots[0]
def settings(s):
 s.render.resolution_percentage=100;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
 s.eevee.taa_render_samples=16
settings(s)
for label,a,f in [('Ready','LongGunReady_LivingRef_V1',25),('Move','LongGunReady_Move_V1',6),('Left','PREVIEW_ONLY_R9W1_Steering_Local',73),('Right','PREVIEW_ONLY_R9W1_Steering_Local',217)]:
 assign(a)
 for view in (['Front','Side'] if quick else ['Front','Gameplay','Opposite','Side','Close','Distance']):
  s.frame_set(f);s.camera=bpy.data.objects['R9W1_'+view]
  s.render.filepath=str(OUT/f'{label}_{view}.png');bpy.ops.render.render(write_still=True)
 if quick:break
if quick:raise SystemExit(0)
for mode,N in [('Ready',96),('Move',64),('Steering',288),('Local',288)]:
 s=bpy.data.scenes['R9W1_REVIEW_'+mode.upper()];bpy.context.window.scene=s;settings(s)
 s.render.resolution_x=1280;s.render.resolution_y=720
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/(mode.lower()+'_AB_24fps.mp4'));s.frame_start=1;s.frame_end=N
 bpy.ops.render.render(animation=True)
 print('RENDERED',mode,flush=True)
print('R9_RENDER_COMPLETE',flush=True)
