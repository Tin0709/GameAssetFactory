"""One live Blender render job per invocation; matched diagnostic A/B stills."""
from onearm_r9w4_common import *
design=json.loads((OUT/'design.json').read_text());job=globals().get('JOB','stills')
if job=='stills':
    files=[]
    for category,data in design['categories'].items():
        s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];s.render.resolution_percentage=100;s.eevee.taa_render_samples=16;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
        for label,key in [('A','baseline_actions'),('B','actions')]:
            for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
                sample(r,s,bpy.data.actions[data[key][mode]],f)
                for view in ['Front','Side','Rear']:
                    s.camera=bpy.data.objects[data['cameras'][view]];path=OUT/f'{category}_{mode}_f{f}_{label}_{view}.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True);files.append(path.name)
    result={'stills':len(files)}
else:
    review=design['reviews'][job];s=bpy.data.scenes[review['scene']];bpy.context.window.scene=s
    s.render.resolution_percentage=100;s.eevee.taa_render_samples=16;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
    end=s.frame_end
    if 'movie_excerpt_frames' in review:s.frame_end=review['movie_excerpt_frames']
    path=OUT/(job+'_AB_24fps.mp4');s.render.filepath=str(path);bpy.ops.render.render(animation=True);count=s.frame_end-s.frame_start+1;s.frame_end=end
    result={'video':str(path),'frames':count,'fps':24,'restored_scene_end':end}
