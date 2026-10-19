"""Render close inspections from the saved source without modifying it."""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Shotgun_Sand_Block_V1.blend'))
s=bpy.context.scene;cam=s.camera
s.render.resolution_x,s.render.resolution_y=1300,950
for name,focus,direction,scale in [
    ('stock_grip',(0,-.260,.050),(.90,.28,.22),.47),
    ('receiver_shells',(.02,.010,.092),(.75,.16,.25),.39),
    ('pump',(.015,.300,.068),(.7,.15,.18),.30),
    ('muzzle',(0,.554,.073),(.65,.55,.18),.28)]:
    focus=Vector(focus);cam.location=focus+Vector(direction)
    cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale
    s.render.filepath=str(OUT/'review'/('detail_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
print('SHOTGUN_DETAILS_RENDERED')
