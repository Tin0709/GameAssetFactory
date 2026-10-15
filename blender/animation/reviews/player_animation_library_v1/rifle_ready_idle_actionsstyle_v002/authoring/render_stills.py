import bpy,sys
from pathlib import Path
O=Path(__file__).resolve().parent.parent;s=bpy.context.scene
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
for frame,label in [(1,'ready'),(115,'look_right'),(40,'look_left')]:
 s.frame_set(frame)
 for view in ['THREE_QUARTER','FRONT','SIDE']:
  s.camera=bpy.data.objects['Showcase_'+view];s.render.filepath=str(O/(label+'_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True)
