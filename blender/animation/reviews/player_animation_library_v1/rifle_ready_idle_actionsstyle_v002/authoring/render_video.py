import bpy,sys,time,json
from pathlib import Path
view=sys.argv[sys.argv.index('--')+1]
O=Path(__file__).resolve().parent.parent;s=bpy.context.scene
s.camera=bpy.data.objects['Showcase_'+view];s.frame_start=1;s.frame_end=240;s.render.fps=30;s.render.fps_base=1.
s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=True
# Eevee gives original-speed reviews with the actual approved materials/lighting.
s.render.engine='CYCLES' if '--cycles' in sys.argv else 'BLENDER_EEVEE'
if hasattr(s,'eevee') and hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=24
s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD'
s.render.filepath=str(O/('rifle_ready_idle_'+view.lower()+'_30fps_1x.mp4'));start=time.time();bpy.ops.render.render(animation=True)
(O/('video_'+view.lower()+'.json')).write_text(json.dumps({'view':view,'fps':30,'frames':240,'duration':8,'closing_frame_excluded':241,'original_speed':True,'renderer':s.render.engine,'elapsed':time.time()-start},indent=2))
