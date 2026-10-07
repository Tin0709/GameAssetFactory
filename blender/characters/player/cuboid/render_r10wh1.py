from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text());job=globals().get('JOB','stills')
if job=='stills':
    files=[]
    for cat,data in design['categories'].items():
        s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
        for label in ['A','B']:
            for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
                sample(r,s,bpy.data.actions[data['baseline_actions' if label=='A' else 'actions'][mode]],f)
                for view,cam in data['cameras'].items():
                    s.camera=bpy.data.objects[cam];s.render.filepath=str(OUT/f'{cat}_{mode}_f{f}_{label}_{view}.png');bpy.ops.render.render(write_still=True);files.append(Path(s.render.filepath).name)
    result={'stills':len(files)}
else:
    row=design['reviews'][job];s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;end=s.frame_end;s.frame_end=row['movie_frames'];s.eevee.taa_render_samples=16;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/(job+'_AB_24fps.mp4'));bpy.ops.render.render(animation=True);s.frame_end=end;result={'movie':job,'frames':row['movie_frames'],'fps':24,'blender_end':end}
