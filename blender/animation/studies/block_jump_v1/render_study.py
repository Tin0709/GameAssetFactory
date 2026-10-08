import bpy,sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.data.scenes['BLOCK_JUMP_V1_REVIEW'];bpy.context.window.scene=s
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
jobs=['Gameplay_Oblique_FIXED','Side_Diagnostic_FIXED']
stills='stills' in args
for name in jobs:
    bpy.context.window.scene=s
    s.camera=bpy.data.objects[name];s.eevee.taa_render_samples=12
    folder=OUT/'.validation'/name;folder.mkdir(exist_ok=True)
    s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
    frames=[1,18,21,25,28,32,36,65,69,75,80,85,91,104] if stills else list(range(1,105))
    for f in frames:
        s.frame_set(f);s.render.filepath=str(folder/f'{f:04d}.png');bpy.ops.render.render(write_still=True)
    print('REVIEW_FRAMES_DONE',name,flush=True)
    if not stills:
        enc=bpy.data.scenes.new('Encode_'+name);bpy.context.window.scene=enc;ed=enc.sequence_editor_create();st=ed.strips.new_image(name,str(folder/'0001.png'),channel=1,frame_start=1)
        for i in range(2,105):st.elements.append(f'{i:04d}.png')
        # Repeat once, keeping the real24fps clock; first cycle and replay identical.
        replay=ed.strips.new_image('REPLAY',str(folder/'0001.png'),channel=1,frame_start=105)
        for i in range(2,105):replay.elements.append(f'{i:04d}.png')
        enc.render.resolution_x=960;enc.render.resolution_y=540;enc.render.resolution_percentage=100;enc.render.fps=24;enc.frame_start=1;enc.frame_end=208;enc.render.use_sequencer=True
        enc.render.image_settings.media_type='VIDEO';enc.render.image_settings.file_format='FFMPEG';enc.render.ffmpeg.format='MPEG4';enc.render.ffmpeg.codec='H264';enc.render.ffmpeg.constant_rate_factor='MEDIUM';enc.render.ffmpeg.ffmpeg_preset='GOOD';enc.render.ffmpeg.audio_codec='NONE';enc.view_settings.view_transform='Standard';enc.view_settings.look='None';enc.render.filepath=str(OUT/('block_jump_'+('gameplay' if name.startswith('Gameplay') else 'side')+'.mp4'))
        bpy.ops.render.render(animation=True)
        print('VIDEO_DONE',enc.render.filepath,flush=True)
