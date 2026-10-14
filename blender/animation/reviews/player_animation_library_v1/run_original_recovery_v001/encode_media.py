import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
contract=json.loads((OUT/'media_contract.json').read_text());report=[]
s=bpy.context.scene;s.render.fps=30;s.frame_start=1;s.frame_end=102
s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH'
s.render.resolution_percentage=100
for c in contract['videos']:
 s.sequence_editor_clear();ed=s.sequence_editor_create();folder=OUT/'panels'/c['name']
 strip=ed.strips.new_image('Native review',str(folder/'001.png'),channel=1,frame_start=1)
 for i in range(1,102):strip.elements.append(f'{i%17+1:03d}.png')
 strip.frame_final_duration=102
 s.render.resolution_x=c['width'];s.render.resolution_y=c['height'];s.render.filepath=str(OUT/(c['name']+'.mp4'))
 bpy.ops.render.render(animation=True)
 movie=bpy.data.movieclips.load(s.render.filepath)
 assert movie.frame_duration==102 and movie.fps==30 and list(movie.size)==[c['width'],c['height']]
 report.append(dict(c,path=Path(s.render.filepath).name,sha256=hashlib.sha256(Path(s.render.filepath).read_bytes()).hexdigest(),bytes=Path(s.render.filepath).stat().st_size,decoded_metadata_verified=True))
assert len(bpy.data.actions)==0
(OUT/'media_validation.json').write_text(json.dumps({'passed':True,'videos':report,'timing':contract['timing'],'no_blend_saved':True},indent=2))
print('SEVEN_NATIVE_REVIEW_VIDEOS_VERIFIED',flush=True)
