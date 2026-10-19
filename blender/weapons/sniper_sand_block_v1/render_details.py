"""Render close inspections from the saved source without modifying it."""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Sniper_Sand_Block_V1.blend'))
s=bpy.context.scene;cam=s.camera
s.cycles.samples=64
s.render.resolution_x,s.render.resolution_y=1300,950
def P(x,y):return Vector((0,(x-137)*.0019,(134-y)*.0019))
for name,px,py,direction,scale in [
    ('stock_grip',95,113,(.95,.27,.22),.40),
    ('receiver_magazine',208,105,(.95,.23,.27),.39),
    ('scope',223,37,(1.0,.55,.30),.52),
    ('muzzle',598,79,(.75,.65,.21),.29)]:
    focus=P(px,py);cam.location=focus+Vector(direction)
    cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale
    s.render.filepath=str(OUT/'review'/('detail_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
print('SNIPER_DETAILS_RENDERED')
