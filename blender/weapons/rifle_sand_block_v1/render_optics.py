"""Saved-asset optic inspection from both ends; does not change the source."""
import bpy
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Rifle_Sand_Block_V1.blend'))
s = bpy.context.scene
s.render.resolution_x,s.render.resolution_y = 1200,900
s.cycles.samples = 48
s.cycles.transmission_bounces = 8
lamp = bpy.data.lights.new('Lens Inspection Reflection','AREA')
lamp.energy,lamp.size,lamp.shape = 18,.32,'RECTANGLE'
lamp.size_y = .075
ob = bpy.data.objects.new('Lens Inspection Reflection',lamp)
s.collection.objects.link(ob)
ob.location = (-.3,-.65,.62)
ob.rotation_euler = (Vector((0,.08,.233))-ob.location).to_track_quat('-Z','Y').to_euler()
cam = s.camera
for name,focus,direction,scale in [
    ('detail_scope_front',(0,.140,.233),(1.0,1.8,.45),.41),
    ('detail_scope_rear',(0,.090,.233),(.65,-1.8,.35),.41),
    ('scope_through_rear',(0,.100,.233),(.004,-2,.003),.22),
]:
    focus = Vector(focus)
    cam.location = focus+Vector(direction)
    cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = scale
    s.render.filepath = str(OUT/'review'/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('OPTIC_REVIEWS_RENDERED')
