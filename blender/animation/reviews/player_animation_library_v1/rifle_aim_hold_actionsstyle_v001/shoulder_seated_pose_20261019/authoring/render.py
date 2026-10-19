import bpy,json,time,sys
from pathlib import Path
from mathutils import Vector
S=Path(__file__).resolve().parent;r=bpy.data.objects['Showcase_Player_Rig'];s=bpy.context.scene;a=bpy.data.actions['Rifle_Aim_Hold_ActionsStyle_v001'];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['reference'];view=args[0];before='before' in args;still='still' in args
s.frame_start=1;s.frame_end=216;s.render.fps=30;s.render.fps_base=1.;s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.engine='BLENDER_EEVEE';s.render.use_file_extension=True
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
c=bpy.data.objects['Showcase_THREE_QUARTER' if view in ['reference','back'] else 'Showcase_'+view.upper()].copy();c.data=c.data.copy();s.collection.objects.link(c)
if view in ['reference','back']:
 c.location=Vector((-6,4,3.3) if view=='back' else (-6,-4,4.6));c.rotation_euler=(Vector((-.05,-.3,1.02))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=2.40
else:c.data.ortho_scale*=1.3
s.camera=c;prefix='before_' if before else 'aim_'
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.frame_set(85);s.render.filepath=str(S/(prefix+view+'.png'));bpy.ops.render.render(write_still=True)
if not (before or still):
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.filepath=str(S/(prefix+view+'_30fps_1x.mp4'));start=time.time();bpy.ops.render.render(animation=True);print('REVIEW_VIDEO_DONE',view,time.time()-start,flush=True)
