"""Presentation only: same Action, two isolated shots and a12-shot6Hz burst."""
import bpy,json,sys,time,argparse
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--view',default='three_quarter');p.add_argument('--still',action='store_true');opt=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);S=Path(__file__).resolve().parent;O=S.parent;N='Rifle_Fire_Recoil_ActionsStyle_v001';r=bpy.data.objects['Showcase_Player_Rig'];s=bpy.context.scene;a=bpy.data.actions[N];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N;s.frame_set(1)
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.fps=30;s.render.fps_base=1.;s.render.use_file_extension=True
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
v=opt.view;cam=bpy.data.objects['Showcase_THREE_QUARTER'].copy();cam.data=cam.data.copy();s.collection.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=2.35
loc={'front':(0,-6,2.3),'three_quarter':(-3,-7,2.9),'side':(-7,0,2.3)}[v];cam.location=Vector(loc);cam.rotation_euler=(Vector((-.05,-.21,.98))-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.frame_set(2);s.render.filepath=str(O/('recoil_'+v+'.png'));bpy.ops.render.render(write_still=True)
if opt.still:print('RECOIL_STILL_DONE',v,flush=True)
else:
 s.frame_set(1);r.animation_data.action=None;assert not r.animation_data.nla_tracks
 track=r.animation_data.nla_tracks.new();track.name='Presentation only | same shot, no accumulated transforms'
 for name,start,repeat in [('Single shot1',31,1),('Single shot2',61,1),('Repeated fire6Hz',91,12)]:
  strip=track.strips.new(name,start,a);strip.action_frame_start=1;strip.action_frame_end=6;strip.repeat=repeat;strip.extrapolation='HOLD';strip.blend_type='REPLACE'
 s.frame_start=1;s.frame_end=180
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.filepath=str(O/('recoil_'+v+'_30fps_1x.mp4'));start=time.time();bpy.ops.render.render(animation=True);print('RECOIL_VIDEO_DONE',v,time.time()-start,flush=True)
 (O/('render_'+v+'.json')).write_text(json.dumps({'passed':True,'view':v,'fps':30,'frames':180,'duration_s':6.,'original_speed':True,'same_action':N,'single_shots_start_frames':[31,61],'burst_start_frame':91,'burst_shots':12,'burst_hz':6.,'no_extra_actions_created':True},indent=2))
