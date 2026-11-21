"""Review cleanup on a local generated mesh. Source color guides are preview-only."""
import json
from math import inf
from pathlib import Path
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render,VIEWS

guides=Path(sys.argv[-2]).resolve()
output=Path(sys.argv[-1]).resolve()
scene=bpy.context.scene
mesh_objects=[o for o in scene.objects if o.type=="MESH"]
assert len(mesh_objects)==1, mesh_objects
obj=mesh_objects[0]
obj.name="GEO-Scout generated surface"
original=len(obj.data.polygons)

# Tiny isolated geometry is discarded by connected-component area (scene-local data).
# Decimation preserves the surface as one piece so clipping/articulation can be assessed.
import bmesh
model=bmesh.new()
model.from_mesh(obj.data)
remaining=set(model.verts)
components=[]
while remaining:
    stack=[remaining.pop()]
    connected=[]
    while stack:
        point=stack.pop()
        connected.append(point)
        for edge in point.link_edges:
            neighbor=edge.other_vert(point)
            if neighbor in remaining:
                remaining.remove(neighbor)
                stack.append(neighbor)
    components.append(connected)
largest=max(len(c) for c in components)
small=[v for c in components if len(c)<largest*.001 for v in c]
if small:
    bmesh.ops.delete(model,geom=small,context="VERTS")
model.to_mesh(obj.data)
model.free()
decimate=obj.modifiers.new("Reference review reduction","DECIMATE")
decimate.ratio=min(1.0,40000/len(obj.data.polygons))
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
bpy.ops.object.modifier_apply(modifier=decimate.name)

# Single set of axis-aligned artwork guides. Adjacent panels share positions at the folds.
# Each color image is local, packed, and fixed to the mesh using native named UVs.
materials={}
coords={}
for face_name in ("front","back","right","left"):
    m=bpy.data.materials.new("MAT-Scout "+face_name+" color guide")
    m.use_nodes=True
    nodes=m.node_tree.nodes
    p=nodes.get("Principled BSDF")
    p.inputs["Roughness"].default_value=.96
    p.inputs["Specular IOR Level"].default_value=.18
    util=nodes.new("ShaderNodeUVMap")
    util.uv_map="Guide UV"
    tex=nodes.new("ShaderNodeTexImage")
    tex.interpolation="Closest"
    tex.extension="EXTEND"
    tex.image=bpy.data.images.load(str(guides/f"{face_name}.png"))
    tex.image.pack()
    mix=nodes.new("ShaderNodeMixRGB")
    mix.blend_type="MIX"
    mix.inputs[0].default_value=.88
    mix.inputs[1].default_value=(.19,.15,.11,1)
    m.node_tree.links.new(util.outputs["UV"],tex.inputs["Vector"])
    m.node_tree.links.new(tex.outputs["Color"],mix.inputs[2])
    m.node_tree.links.new(mix.outputs[0],p.inputs["Base Color"])
    materials[face_name]=m
    coords[face_name]={"front":(0,1),"back":(0,-1),"right":(1,-1),"left":(1,1)}[face_name]
obj.data.materials.clear()
for m in materials.values():
    obj.data.materials.append(m)
layer=obj.data.uv_layers.new(name="Guide UV")
world=obj.matrix_world
soles=[world@v.co for v in obj.data.vertices if (world@v.co).z<.12]
anchors=[(min(v[i] for v in soles)+max(v[i] for v in soles))/2 for i in (0,1)]
rotation=world.to_3x3().inverted().transposed()
for face in obj.data.polygons:
    n=rotation@face.normal
    if abs(n.y)>=abs(n.x):
        name="front" if n.y<0 else "back"
    else:
        name="right" if n.x<0 else "left"
    face.material_index=list(materials).index(name)
    axis,sign=coords[name]
    for i in face.loop_indices:
        v=world@obj.data.vertices[obj.data.loops[i].vertex_index].co
        layer.data[i].uv=(.5+sign*(v[axis]-anchors[axis])*52/1.8/64,(6+v.z*52/1.8)/64)
    face.use_smooth=True
bpy.context.preferences.filepaths.save_version=0
scene.name="Scout · Hunyuan refined preview"
render(scene,[(1,v,bpy.data.objects["CAM-"+v]) for v,_,_ in VIEWS],output)
scene.render.filepath="//scout-generated.png"
bpy.ops.wm.save_as_mainfile(filepath=str(output/"Scout generated review.blend"),compress=True)
bpy.ops.export_scene.gltf(filepath=str(output/"Scout generated review.glb"),export_format="GLB",
                          use_selection=True,export_cameras=False,export_lights=False)
(output/"cleanup.json").write_text(json.dumps({"raw_faces":original,"faces_after_cleanup":len(obj.data.polygons),
    "removed_small_vertices":len(small),"components_before":len(components),"texture":[64,64],"rigged":False},indent=2),encoding="utf8")


