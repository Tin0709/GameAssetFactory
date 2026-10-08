import bpy,json
from pathlib import Path
from mathutils import Vector
D=Path(__file__).resolve().parent;bpy.ops.wm.open_mainfile(filepath=str(D/'environment_scatter_set_v1.blend'));s=bpy.context.scene
for o in s.objects:o.hide_render=not(o.type=='LIGHT' or o.name=='Studio Ground')
s.cycles.samples=24;s.render.resolution_x=500;s.render.resolution_y=500;cam=bpy.data.objects['REVIEW • flowers'];s.camera=cam
manifest=json.loads((D/'manifest.json').read_text())
for entry in manifest['new_assets']:
 o=bpy.data.objects[entry['name']];o.hide_render=False;o.location.z=-.04
 center=o.location+Vector((0,0,o.dimensions.z*.45));maxdim=max(o.dimensions);cam.location=center+Vector((1.5,-2,2.2))*maxdim;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=maxdim*1.65
 s.render.filepath=str(D/entry['thumbnail']);bpy.ops.render.render(write_still=True);o.hide_render=True
print('THUMBNAILS_GROUNDED_READY')
