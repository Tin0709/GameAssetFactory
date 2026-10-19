"""Detail views from the saved pistol source; no source mutations."""
import bpy
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pistol_Sand_Block_V1.blend'))
s = bpy.context.scene
s.render.resolution_x,s.render.resolution_y = 1200,900
cam = s.camera
for name,focus,direction,scale in [
    ('rear_sight',(0,-.007,.102),(.28,-.40,.17),.160),
    ('slide',(0,.058,.091),(.50,.10,.20),.245),
    ('muzzle',(0,.176,.083),(.35,.35,.14),.155),
    ('grip',(0,-.015,-.001),(.40,.17,.11),.195),
]:
    focus = Vector(focus)
    cam.location = focus+Vector(direction)
    cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = scale
    s.render.filepath = str(OUT/'review'/('detail_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
print('PISTOL_DETAILS_RENDERED')
