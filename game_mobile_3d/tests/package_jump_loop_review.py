"""Encode and inspect actual Godot pixels. Does not edit or save Blender art."""
import json, sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'.validation/jump_loop_v003'
if '--encode' in sys.argv:
    import bpy
    scene=bpy.context.scene;scene.sequence_editor_create()
    strip=scene.sequence_editor.strips.new_movie('Actual WorldMap',str(OUT/'gameplay.avi'),channel=1,frame_start=1)
    scene.frame_start=1;scene.frame_end=strip.frame_duration-2
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.render.fps=30;scene.render.use_sequencer=True
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    scene.render.image_settings.media_type='VIDEO';scene.render.image_settings.file_format='FFMPEG'
    scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264'
    scene.render.ffmpeg.constant_rate_factor='HIGH';scene.render.ffmpeg.audio_codec='NONE'
    scene.render.filepath=str(OUT/'gameplay.mp4');bpy.ops.render.render(animation=True)
else:
    import cv2
    from PIL import Image,ImageDraw
    rows=json.loads((OUT/'capture.json').read_text())['frames']
    chosen=[]
    for section in dict.fromkeys(r['section'] for r in rows if r['section']):
        relevant=[r for r in rows if r['section']==section]
        apex=max(relevant,key=lambda r:r['position'][1])
        chosen.extend([max(relevant[0]['frame'],apex['frame']-9),apex['frame'],apex['frame']+8])
    cap=cv2.VideoCapture(str(OUT/'gameplay.mp4'));fps=cap.get(cv2.CAP_PROP_FPS)
    decoded=0
    while True:
        ok,_=cap.read()
        if not ok:break
        decoded+=1
    assert decoded>=600 and abs(fps-30)<.01
    sheet=Image.new('RGB',(1280,(len(chosen)//3)*265),'#171d20');draw=ImageDraw.Draw(sheet)
    for i,frame in enumerate(chosen):
        cap.set(cv2.CAP_PROP_POS_FRAMES,frame);ok,bgr=cap.read();assert ok
        im=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB));im.save(OUT/f'frame_{frame:03d}.png')
        im.thumbnail((426,240));x=(i%3)*426;y=(i//3)*265;sheet.paste(im,(x,y))
        draw.text((x+4,y+242),f"F{frame} / {rows[frame]['section']}",fill='white')
    cap.release();sheet.save(OUT/'contact_sheet.jpg',quality=94)
    report={'decoded_frames':decoded,'fps':fps,'duration':decoded/fps,'sampled_frames':chosen,'origin':'actual WorldMap Mobile renderer recording; no Blender-generated gameplay frames'}
    (OUT/'video_checks.json').write_text(json.dumps(report,indent=2));print(report)
