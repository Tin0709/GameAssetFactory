"""Finish the Scout's rear hood fold and paint the cloak in joined square swatches."""
from pathlib import Path
import random
import sys

import bpy

ROOT = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

S = 1.8/518
P = "Scout Canon | "
B = "Scout Blocks | "
scene = bpy.context.scene
scene.frame_set(1)
out = Path(sys.argv[-1]).resolve()

hood = scene.objects[P + "Rear folded hood panel"]
for vertex, z in ((38, 422),(39,425),(40,411),(41,425),(42,422)):
    hood.data.vertices[vertex].co.z = z*S
hood.data.update()

dye = bpy.data.materials[B + "Ochre binding"].node_tree.nodes["Warm cloth dye"]
dye.inputs[2].default_value = (.84,.80,.72,1)

cloak = scene.objects[P + "Long cloak with tapered supporting folds"]
base = bpy.data.materials["Scout Square | 64 by 64 materials"]
source = next(n.image for n in base.node_tree.nodes if n.type == "TEX_IMAGE")
colors = list(source.pixels)

def swatch(cell, u, v):
    index = ((cell//4*16+v)*64 + cell%4*16+u)*4
    return tuple(colors[index:index+3])

olive = swatch(2,8,8)
shade = swatch(13,6,9)
ochre = swatch(1,10,9)
gold = swatch(0,4,4)
def blend(a,b,t):
    return tuple(x+(y-x)*t for x,y in zip(a,b))

# Keep squares grouped into broad fabric swatches. Gold is concentrated on
# alternating cloth ends, including the short tab to the right of center.
image = bpy.data.images.new("Scout · Cloak patchwork 64×64",width=64,height=64,alpha=False)
cols, rows = 26, 35
rng = random.Random(721)
variation = [[rng.choice((-.02,0,.01,.025,.038)) for _ in range(cols//2+1)] for _ in range(rows//2+1)]
# (first column, width, height, hue mix) for each ochre hem section.
ends = [(2,3,12,.46),(6,2,10,.60),(9,3,8,.32),(12,2,9,.65),
        (16,3,10,.41),(20,2,12,.52),(23,2,13,.34)]
pixels = list((*olive,1)*4096)
for y in range(rows):
    for x in range(cols):
        a = .17 if x in (1,5,10,15,20,24) else .0
        if y > 27:
            a += .15
        color = blend(olive,shade,a)
        for left,width,height,mix in ends:
            if left<=x<left+width and y < height-(1 if x==left and width>2 else 0):
                color = blend(color,blend(ochre,gold,.14),mix)
                break
        if (x//3 + y//4)%4 == 1:
            color = blend(color,ochre,.12)
        value = variation[(y+(x//5)%2)//2][(x+(y//8)%2)//2]
        index = (y*64+x)*4
        pixels[index:index+3] = [max(0,min(1,c*(1+value))) for c in color]
image.pixels.foreach_set(pixels)
image.pack()

material = bpy.data.materials.new("Scout · Cloak patched olive and ochre")
material.use_nodes = True
nodes = material.node_tree.nodes
cloth = nodes.get("Principled BSDF")
cloth.inputs["Roughness"].default_value = .92
cloth.inputs["Specular IOR Level"].default_value = .20
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
tex.interpolation = "Closest"
uv_map = nodes.new("ShaderNodeUVMap")
uv_map.uv_map = "Scout Cloak UV"
material.node_tree.links.new(uv_map.outputs["UV"],tex.inputs["Vector"])
material.node_tree.links.new(tex.outputs["Color"],cloth.inputs["Base Color"])
mesh = cloak.data
mesh.materials.append(material)
uv = mesh.uv_layers.new(name=uv_map.uv_map)
for face in mesh.polygons:
    if face.normal.y < .27 or face.center.z/S > 260:
        continue
    face.material_index = len(mesh.materials)-1
    for loop in face.loop_indices:
        x,y,z = mesh.vertices[mesh.loops[loop].vertex_index].co/S
        u = .5+(cols-1)*max(0,min(1,(x+85)/166))
        v = .5+(rows-1)*max(0,min(1,(z-105)/180))
        uv.data[loop].uv = (u/64,v/64)

scene["Source-fit pass"] = "Fitted rectangular details · patchwork cloak and hood fold"
markers = {m.name.casefold():m for m in scene.timeline_markers if m.camera}
render(scene,[(markers[v].frame,v,markers[v].camera) for v in ("front","hero","right","back","left")],out)
scene.render.filepath = "//Scout review.png"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

