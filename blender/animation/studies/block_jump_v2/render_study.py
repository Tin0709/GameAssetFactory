import bpy,sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.data.scenes['BLOCK_JUMP_V2_REVIEW'];bpy.context.window.scene=s
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
jobs=['Gameplay_Oblique_FIXED','Side_Diagnostic_FIXED']
stills='stills' in args
for name in jobs:
    bpy.context.window.scene=s
    s.camera=bpy.data.objects[name];s.eevee.taa_render_samples=12
    folder=OUT/'.validation'/name;folder.mkdir(exist_ok=True)
    s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
    frames=[1,18,21,22,25,28,32,36,75,79,83,87,92,104,126,132,183,187,191] if stills else list(range(1,209))
    for f in frames:
        if 'reuseframes' in args and (folder/f'{f:04d}.png').exists():continue
        s.frame_set(f);s.render.filepath=str(folder/f'{f:04d}.png');bpy.ops.render.render(write_still=True)
    print('REVIEW_FRAMES_DONE',name,flush=True)
    if not stills:
        enc=bpy.data.scenes.new('Encode_'+name);bpy.context.window.scene=enc;ed=enc.sequence_editor_create();st=ed.strips.new_image(name,str(folder/'0001.png'),channel=1,frame_start=1)
        for i in range(2,209):st.elements.append(f'{i:04d}.png')
        for start,label in [(1,'V2 / A'),(105,'V2 / B - opposite lead')]:
            title=ed.strips.new_effect(label,type='TEXT',channel=2,frame_start=start,length=104)
            title.text=label;title.font_size=24;title.location=(.04,.95);title.alignment_x='LEFT';title.anchor_x='LEFT';title.anchor_y='TOP';title.use_shadow=True;title.blend_type='ALPHA_OVER'
        enc.render.resolution_x=960;enc.render.resolution_y=540;enc.render.resolution_percentage=100;enc.render.fps=24;enc.frame_start=1;enc.frame_end=208;enc.render.use_sequencer=True
        enc.render.image_settings.media_type='VIDEO';enc.render.image_settings.file_format='FFMPEG';enc.render.ffmpeg.format='MPEG4';enc.render.ffmpeg.codec='H264';enc.render.ffmpeg.constant_rate_factor='MEDIUM';enc.render.ffmpeg.ffmpeg_preset='GOOD';enc.render.ffmpeg.audio_codec='NONE';enc.view_settings.view_transform='Standard';enc.view_settings.look='None';enc.render.filepath=str(OUT/('block_jump_'+('gameplay' if name.startswith('Gameplay') else 'side')+'.mp4'))
        bpy.ops.render.render(animation=True)
        print('VIDEO_DONE',enc.render.filepath,flush=True)
