"""Use the original manual studio lighting with its strictly geometry-only alpha."""
import argparse
from pathlib import Path
from PIL import Image

p=argparse.ArgumentParser(description=__doc__)
p.add_argument("studio_render",type=Path)
p.add_argument("geometry_mask",type=Path)
p.add_argument("out",type=Path)
a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
for view in ("front","hero","right","back","left"):
    rgb=Image.open(a.studio_render/f"{view}.png").convert("RGBA")
    alpha=Image.open(a.geometry_mask/f"{view}.png").convert("RGBA").getchannel("A")
    assert rgb.size==alpha.size
    rgb.putalpha(alpha)
    rgb.save(a.out/f"{view}.png")

