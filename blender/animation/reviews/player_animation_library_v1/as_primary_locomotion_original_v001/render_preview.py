"""Normal-time source-action preview frames from the saved central comparison."""
import bpy,json
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[4]
s=bpy.data.scenes['ASPrimary_WalkRun_Comparison_PENDING'];bpy.context.window.scene=s
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=960;s.render.resolution_y=600;s.render.resolution_percentage=100
sh=s.display.shading;sh.light='STUDIO';sh.color_type='TEXTURE';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.show_specular_highlight=False;sh.background_type='WORLD'
s.display.render_aa='8';s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard'
out=R/'.validation/animation_showcase/as_primary_locomotion_original_v001/preview_frames';out.mkdir(exist_ok=True)
for i in range(75):
 s.frame_set(1+2*i);s.render.filepath=str(out/('%03d.png'%i));bpy.ops.render.render(write_still=True,scene=s.name)
print('PREVIEW_RENDERED_75_FRAMES_30HZ',flush=True)
