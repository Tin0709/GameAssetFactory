import bpy
from pathlib import Path
import sys,json
out=Path(sys.argv[-1]).resolve()
out.mkdir(parents=True,exist_ok=True)
palettes={"hood":"hood-cloth-64.png","older_hood":"Scout Hood Study | Pixel color blocks 64x64",
          "outer":"Scout Outerwear | Packed 64x64", "trim":"Scout Square | Tailored atlas",
          "body":"Scout \u2022 Tailoring atlas 64x64"}
for name,key in palettes.items():
    im=bpy.data.images[key]
    assert im.packed_file and list(im.size)==[64,64]
    (out/(name+".png")).write_bytes(bytes(im.packed_file.data))
for m in bpy.data.materials:
    if m.users>0 and m.use_nodes:
        print(m.name,[(n.type,n.name) for n in m.node_tree.nodes if n.type in ("MIX_RGB","TEX_IMAGE")])

