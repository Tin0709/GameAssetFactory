"""Actual Blender full-body and cloth-detail reviews. Never save render setup."""
from pathlib import Path
import bpy, sys
from mathutils import Vector
D=Path(__file__).resolve().parent
sys.path.insert(0,str(D.parents[1]/'showcase'))
bpy.ops.wm.open_mainfile(filepath=str(D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
import soldier_library_ui
soldier_library_ui.register()
bpy.ops.soldier_hair.compare(variant='BANDANA')
s=bpy.context.scene;s.soldier_hair.closeup=False
out=D/'review';out.mkdir(exist_ok=True)
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=64
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.resolution_percentage=100
s.render.resolution_x=720;s.render.resolution_y=1080;s.render.film_transparent=False
for direction in ['Front','ThreeQuarter','Side','Back','BackThreeQuarter']:
    bpy.ops.soldier_hair.view(direction=direction)
    s.render.filepath=str(out/('WORN_'+direction+'.png'));bpy.ops.render.render(write_still=True)
data=bpy.data.cameras.new('WC_Temporary_Detail');data.type='ORTHO';data.ortho_scale=.85
cam=bpy.data.objects.new('WC_Temporary_Detail',data);s.collection.objects.link(cam);s.camera=cam
for name,target,scale in [('Shirt_Detail',(0,0,1.020),.90),('Trouser_Detail',(0,0,.360),.79)]:
    cam.location=(0,-4,target[2]+.24);cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=scale
    s.render.resolution_x=s.render.resolution_y=720;s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('WORN_REVIEW_RENDERED',str(out),flush=True)
