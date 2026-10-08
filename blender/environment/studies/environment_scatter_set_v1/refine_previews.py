import bpy, json, hashlib, bmesh
from pathlib import Path
from mathutils import Vector
D=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(D/'environment_scatter_set_v1.blend'))
s=bpy.context.scene
image=bpy.data.images['SCATTER_Palette_128_Opaque'];pixels=list(image.pixels)
for i in range(3,len(pixels),4):pixels[i]=1
image.pixels.foreach_set(pixels);image.update();image.pack()
for o in bpy.data.objects:
 if o.type=='FONT':o.visible_shadow=False
for color,rgb in {'purple':(.14,.065,.20),'yellow':(.22,.15,.028),'white':(.20,.22,.18),'red':(.24,.045,.038)}.items():
 ma=bpy.data.materials['LABEL • '+color];ma.diffuse_color=(*rgb,1);ma.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*rgb,1)
bpy.data.objects['Reference header'].location.y=3.02
assets=[o for o in bpy.data.objects if o.get('scatter_asset')]
# Weld the exposed voxel surfaces; no bevel, subdivision or smoothing.
for o in assets:
 if o['category'] in ('rock','dirt'):
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bm.to_mesh(o.data);bm.free();o.data.update()
s.camera=bpy.data.objects['REVIEW • overview'];s.render.filepath=str(D/'preview_overview.png');s.render.resolution_x=1600;s.render.resolution_y=1150;bpy.ops.render.render(write_still=True)
for name in ('rocks','ground','flowers','v4_compatibility'):
 s.camera=bpy.data.objects['REVIEW • '+('V4 compatibility' if name=='v4_compatibility' else name)]
 s.render.resolution_x=1400;s.render.resolution_y=460 if name!='v4_compatibility' else 1000
 s.render.filepath=str(D/('preview_'+name+'.png'));bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['REVIEW • overview'];s.render.resolution_x=1600;s.render.resolution_y=1150;s.render.filepath=str(D/'preview_overview.png');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(D/'environment_scatter_set_v1_refined.blend'))
# Render thumbnails from the same saved scene; these temporary visibility/camera changes are not saved.
thumbdir=D/'thumbnails';thumbdir.mkdir(exist_ok=True)
for o in s.objects:o.hide_render=not (o.type=='LIGHT' or o.name=='Studio Ground')
s.cycles.samples=24;s.render.resolution_x=500;s.render.resolution_y=500
cam=bpy.data.objects['REVIEW • flowers'];s.camera=cam
manifest=json.loads((D/'manifest.json').read_text());thumbs={}
for entry in manifest['new_assets']:
 o=bpy.data.objects[entry['name']];o.hide_render=False
 center=o.location+Vector((0,0,o.dimensions.z*.45));maxdim=max(o.dimensions);cam.location=center+Vector((1.5,-2,2.2))*maxdim;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=maxdim*1.65
 s.render.filepath=str(thumbdir/(o.name+'.png'));bpy.ops.render.render(write_still=True);o.hide_render=True;entry['thumbnail']='thumbnails/'+o.name+'.png';entry['vertices']=len(o.data.vertices);o.data.calc_loop_triangles();entry['triangles']=len(o.data.loop_triangles)
(D/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('REFINEMENT_AND_18_THUMBNAILS_READY')

