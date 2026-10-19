import bpy,json,time,hashlib,sys
from pathlib import Path
from mathutils import Matrix,Vector
import argparse
p=argparse.ArgumentParser();p.add_argument('--cache',required=True);opt=p.parse_args(sys.argv[sys.argv.index('--')+1:]);S=Path(opt.cache).resolve();r=bpy.data.objects['Showcase_Player_Rig'];s=bpy.context.scene;a=bpy.data.actions['Crossbow_Aim_ActionsStuff_Source_Test_v001'];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_start=1;s.frame_end=216;s.render.fps=30;s.render.fps_base=1.;s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.engine='BLENDER_EEVEE';s.render.use_file_extension=True
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
# Presentation-only zoom: every original camera datablock in the source/Showcase stays untouched on disk.
mirror=Matrix.Diagonal(Vector((-1.,1.,1.,1.)));op=bpy.data.objects['Showcase_THREE_QUARTER'].copy();op.data=op.data.copy();op.name='Showcase_THREE_QUARTER_OPPOSITE';s.collection.objects.link(op);op.matrix_world=mirror@op.matrix_world@mirror
for view in ['FRONT','THREE_QUARTER','SIDE']:
 camera=bpy.data.objects['Showcase_'+view];camera.data=camera.data.copy();camera.data.ortho_scale*=1.18;s.camera=camera
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.filepath=str(S/('aim_'+view.lower()+'_30fps_1x.mp4'));start=time.time();bpy.ops.render.render(animation=True)
 print('AIM_VIDEO_DONE',view,time.time()-start,flush=True)
 s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.frame_set(85);s.render.filepath=str(S/('aim_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True)
(S/'render_manifest.json').write_text(json.dumps({'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'fps':30,'frames':216,'duration_s':7.2,'original_speed':True,'views':['front','three_quarter','side','three_quarter_opposite'],'source_period_s':3.6,'two_complete_cycles':True,'closing_frame_excluded':217,'renderer':'BLENDER_EEVEE'},indent=2))
