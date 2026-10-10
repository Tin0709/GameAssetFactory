"""Temporary factory-startup encoder. Never loads or saves the source study."""
import bpy,sys
from pathlib import Path
folder,output,count=sys.argv[sys.argv.index('--')+1:];folder=Path(folder);count=int(count)
s=bpy.context.scene;e=s.sequence_editor_create()
first=bpy.data.images.load(str(folder/'0001.png'));width,height=first.size
strip=e.strips.new_image('Actual Blender render frames',str(folder/'0001.png'),channel=1,frame_start=1)
for f in range(2,count+1):strip.elements.append(f'{f:04d}.png')
s.render.resolution_x=width;s.render.resolution_y=height;s.render.resolution_percentage=100
s.render.fps=30;s.frame_start=1;s.frame_end=count;s.render.use_sequencer=True
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.audio_codec='NONE'
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.render.filepath=output
bpy.ops.render.render(animation=True,scene=s.name)
print('ENCODED',output,count,flush=True)
