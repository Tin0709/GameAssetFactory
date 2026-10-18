import bpy,sys,time
from pathlib import Path
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects[ui.RIG]
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24;s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.fps=30;s.render.fps_base=1.;s.render.threads_mode='FIXED';s.render.threads=6
for kind,name in [('Run','Rifle_Ready_Run_ActionsStyle_v002')]:
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=name;ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
 s.frame_set(6);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
 for view in ['THREE_QUARTER','FRONT','SIDE']:
  s.camera=bpy.data.objects['Showcase_'+view];s.render.filepath=str(O/(kind.lower()+'_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True)
 s.frame_start=1;s.frame_end=144;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD'
 for view in ['THREE_QUARTER','FRONT','SIDE']:
  s.camera=bpy.data.objects['Showcase_'+view];s.render.filepath=str(O/(kind.lower()+'_'+view.lower()+'_30fps_1x.mp4'));t=time.time();bpy.ops.render.render(animation=True);print('RENDERED',kind,view,time.time()-t,flush=True)
