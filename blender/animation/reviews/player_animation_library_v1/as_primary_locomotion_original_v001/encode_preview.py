"""Encode the 75 actual Blender renders at a 30Hz average, no interpolation."""
from pathlib import Path
import json
from PIL import Image
H=Path(__file__).resolve().parent;R=H.parents[4]
folder=R/'.validation/animation_showcase/as_primary_locomotion_original_v001/preview_frames'
paths=sorted(folder.glob('*.png'));assert len(paths)==75
frames=[]
for p in paths:
 with Image.open(p)as im:frames.append(im.convert('RGB').quantize(colors=192))
duration=[30,30,40]*25
out=H/'Walk_Run_Original_Pending.gif'
frames[0].save(out,save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=False,disposal=2)
with Image.open(out)as im:
 assert im.n_frames==75
 total=0
 for i in range(im.n_frames):im.seek(i);total+=im.info['duration']
 assert total==2500,total
(H/'preview_metadata.json').write_text(json.dumps({'frames':75,'rendered_action_frames':'1,3,...149 at60fps','duration_ms':total,'average_preview_fps':30,'interpolated_frames':False,'source':'actual original saved Blender source Actions, same stage functions as central','size_bytes':out.stat().st_size},indent=2),encoding='utf8')
print(out,total,'ms',out.stat().st_size,'bytes')
