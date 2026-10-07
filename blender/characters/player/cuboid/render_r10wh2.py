from hold_r10wh2_common import *
design=json.loads((OUT/'design.json').read_text());job=globals().get('JOB','stills')
if job=='stills':
    files=[]
    for cat,d in design['categories'].items():
        s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
        for tag in ['A','B']:
            for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
                sample(r,s,bpy.data.actions[d['baseline_actions' if tag=='A' else 'actions'][mode]],f)
                for view,cam in d['cameras'].items():
                    s.camera=bpy.data.objects[cam];s.render.filepath=str(OUT/f'{cat}_{mode}_f{f}_{tag}_{view}.png');bpy.ops.render.render(write_still=True);files.append(s.render.filepath)
    for mode,f in [('Hold',25),('AimAround',73)]:
        s=bpy.data.scenes[design['showcases'][mode]['scene']];bpy.context.window.scene=s;s.frame_set(f);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/f'Showcase_{mode}_f{f}.png');bpy.ops.render.render(write_still=True);files.append(s.render.filepath)
    result={'stills':len(files)}
else:
    d=design['showcases'][job[9:]] if job.startswith('Showcase_') else design['reviews'][job];s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;end=s.frame_end;s.frame_end=d['movie_frames'];s.eevee.taa_render_samples=16;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/(job+'_24fps.mp4'));bpy.ops.render.render(animation=True);s.frame_end=end;result={'movie':job,'frames':d['movie_frames'],'fps':24}
