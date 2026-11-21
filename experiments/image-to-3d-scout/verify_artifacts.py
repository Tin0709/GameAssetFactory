"""Verify packed 64px textures, rig attachment and the generated GLB round-trip."""
import bpy
from pathlib import Path
import hashlib
import json
import sys

folder=Path(sys.argv[-1]).resolve()
manual=folder/"tailoring-3"/"Scout pixel tailoring.blend"
result=folder/"multi-refined"/"Scout generated review.glb"
bpy.ops.wm.open_mainfile(filepath=str(manual),load_ui=False)
s=next(s for s in bpy.data.scenes if s.name.startswith("Scout · Pixel"))
rig=s.objects["Scout Canon | Rig"]
meshes=[o for o in s.objects if o.type=="MESH"]
assert len(meshes)>60 and all(o.parent==rig and o.parent_bone in rig.data.bones for o in meshes)
packed=[list(i.size) for i in bpy.data.images if i.packed_file]
assert len(packed)==3 and all(size==[64,64] for size in packed)
candidate={"objects":len(meshes),"rig_bones":len(rig.data.bones),"packed_texture_sizes":packed,
           "sha256":hashlib.sha256(manual.read_bytes()).hexdigest()}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(result))
objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
faces=sum(len(o.data.polygons) for o in objects)
assert faces==40000
assert len([i for i in bpy.data.images if tuple(i.size)==(64,64)])==4
roundtrip={"faces":faces,"size":result.stat().st_size,"texture_count":4,"rigged":False,"sha256":hashlib.sha256(result.read_bytes()).hexdigest()}
report={"modular_blender":candidate,"generated_glb_reimport":roundtrip}
(folder/"artifact-verification.json").write_text(json.dumps(report,indent=2),encoding="utf8")
print(json.dumps(report))

