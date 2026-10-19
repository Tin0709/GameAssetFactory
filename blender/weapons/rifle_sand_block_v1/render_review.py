"""Render the saved source with a ground height fitted to its final silhouette."""
import bpy
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Rifle_Sand_Block_V1.blend'))
s = bpy.context.scene
c = bpy.data.collections['WEAPON_EXPORT']
minimum = min((o.matrix_world@v.co).z for o in c.all_objects if o.type == 'MESH' for v in o.data.vertices)
bpy.data.objects['Review_Ground'].location.z = minimum-.0007
floor = bpy.data.materials['Graphite Floor'].node_tree.nodes.get('Principled BSDF')
floor.inputs['Base Color'].default_value = (.006,.007,.009,1)
for name, energy in [('Key',130),('Fill',68),('Rim',150)]:
    bpy.data.lights[name].energy = energy
focus = Vector((0,.263,.070))
cam = s.camera
for name, direction in [('three_quarter',(1.65,.85,.52)),('side',(2,0,.05)),
                        ('top',(.001,0,2)),('front',(0,2,.03))]:
    cam.location = focus+Vector(direction)
    cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = 1.39 if name != 'front' else .66
    s.render.filepath = str(OUT/'review'/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('REVIEW_RENDERED',flush=True)
