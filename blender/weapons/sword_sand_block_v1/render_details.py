"""Close inspections of the saved sword; never resave the source."""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Sword_Sand_Block_V1.blend'))
s=bpy.context.scene;cam=s.camera
s.render.resolution_x,s.render.resolution_y=1300,950
s.cycles.samples=48
for name,px,direction,scale in [
    ('guard',177,(.85,.35,.27),.34),
    ('blade',375,(1,.26,.28),.49),
    ('tip',581,(.80,.45,.27),.31),
    ('grip_pommel',97,(.85,-.46,.26),.35)]:
    focus=Vector((0,(px-116)*.0019,0));cam.location=focus+Vector(direction)
    cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale;s.render.filepath=str(OUT/'review'/('detail_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
print('SWORD_DETAILS_RENDERED')
