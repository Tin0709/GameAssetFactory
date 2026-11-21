"""Verify the saved Forager asset against the source rig and render shape checks."""
from pathlib import Path
import json
import sys

import bmesh
import bpy

source,out = (Path(arg).resolve() for arg in sys.argv[-2:])
scene = bpy.context.scene
rig = scene.objects["The Forager | Minecraft rig"]
asset = bpy.data.collections["The Forager"]
meshes=[o for o in asset.all_objects if o.type=="MESH"]
assert len(meshes)>45
assert not bpy.data.libraries
assert all(o.parent==rig and o.parent_type=="BONE" and o.parent_bone for o in meshes)
assert not any(o.name.lower().startswith(("spear","backpack","lantern","boot","leg")) for o in meshes)
assert all(len(m.data.uv_layers)>0 for m in meshes)
assert rig.animation_data is None
packed=set()
for obj in meshes:
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in bm.edges),obj.name
    assert all(f.calc_area()>1e-10 for f in bm.faces),obj.name
    bm.free()
    for material in obj.data.materials:
        image_nodes=[node for node in material.node_tree.nodes if node.type=="TEX_IMAGE"]
        assert image_nodes and all(n.interpolation=="Closest" for n in image_nodes)
        for node in image_nodes:
            assert node.image.packed_file and tuple(node.image.size)==(64,64),material.name
            packed.add(node.image.name)

with bpy.data.libraries.load(str(source),link=False) as (source_file,objects):
    assert "Showcase_Player_Rig" in source_file.objects
    objects.objects=["Showcase_Player_Rig"]
raw=objects.objects[0].data
assert len(rig.data.bones)==len(raw.bones)==13
difference=0
for bone in rig.data.bones:
    original=raw.bones[bone.name]
    assert (bone.parent.name if bone.parent else None)==(original.parent.name if original.parent else None)
    assert abs(bone.length-original.length)<1e-6
    delta = bone.matrix_local-original.matrix_local
    difference=max(difference,max(abs(v) for row in delta for v in row))
assert difference<1e-6

out.mkdir(exist_ok=True,parents=True)
(out/"verification.json").write_text(json.dumps({
    "rig": "Animation_Showcase.blend · Showcase_Player_Rig",
    "bones":len(rig.data.bones),"max_rest_matrix_delta":difference,
    "closed_material_meshes":len(meshes),
    "packed_nearest_64x64_textures":sorted(packed),
    "scene_camera":scene.camera.name,
},indent=2,ensure_ascii=False),encoding="utf8")

clay=bpy.data.materials.new("Shape check · gray clay")
clay.use_nodes=True
shader=clay.node_tree.nodes.get("Principled BSDF")
shader.inputs["Base Color"].default_value=(.36,.33,.31,1)
shader.inputs["Roughness"].default_value=.93
scene.view_layers[0].material_override=clay
scene.render.resolution_x=670
scene.render.resolution_y=790
scene.cycles.samples=24
for key in ("Front","Hero"):
    marker=next(m for m in scene.timeline_markers if m.name==key)
    scene.frame_set(marker.frame)
    scene.camera=marker.camera
    scene.render.filepath=str(out/f"clay-{key.lower()}.png")
    bpy.ops.render.render(write_still=True)

