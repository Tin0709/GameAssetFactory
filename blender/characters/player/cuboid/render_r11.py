from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());job=globals().get('JOB','stills')
if job=='stills':
    files=[]
    for cat,d in design['categories'].items():
        s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];s.render.resolution_x=900;s.render.resolution_y=850;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
        for tag in ['A','B']:
            next(bpy.data.objects[n] for n in d['weapons'] if '_Base' in n).parent.scale=(d['baseline_scale'],)*3 if tag=='A' else d['study_weapon_scale']
            sample(r,s,bpy.data.actions[d['baseline_actions' if tag=='A' else 'actions']['Hold']],25)
            for view,c in d['cameras'].items():
                s.camera=bpy.data.objects[c];s.render.filepath=str(OUT/(cat+'_'+tag+'_'+view+'.png'));bpy.ops.render.render(write_still=True);files.append(s.render.filepath)
        assign(r,bpy.data.actions[d['actions']['Hold']]);s.frame_set(25)
    s=bpy.data.scenes[design['showcases']['Hold']['scene']];bpy.context.window.scene=s;s.frame_set(25);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'ThreeWeapon_R11.png');bpy.ops.render.render(write_still=True)
    result={'AB_images':len(files),'showcase':s.render.filepath}
elif job=='showcase_still':
    s=bpy.data.scenes[design['showcases']['Hold']['scene']];bpy.context.window.scene=s;s.frame_set(25);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'ThreeWeapon_R11.png');bpy.ops.render.render(write_still=True);result={'showcase':s.render.filepath}
else:
    d=design['showcases'][job];s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;s.frame_start=1;s.frame_end=d['frames'];s.render.resolution_x=1350;s.render.resolution_y=600;s.eevee.taa_render_samples=8;s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/(job+'_24fps.mp4'));bpy.ops.render.render(animation=True);result={'mode':job,'frames':d['frames'],'file':s.render.filepath}
    manifest={'actions':{cat:{'name':data['upper'],'digest':digest(bpy.data.actions[data['upper']])} for cat,data in d['actors'].items()},'sha256':hashlib.sha256(Path(s.render.filepath).read_bytes()).hexdigest(),'frames':d['frames'],'offsets':GUN_OFFSET,'weapon_scales':STUDY_GUN_SCALE}
    (OUT/(job+'_render_manifest.json')).write_text(json.dumps(manifest,indent=2))
