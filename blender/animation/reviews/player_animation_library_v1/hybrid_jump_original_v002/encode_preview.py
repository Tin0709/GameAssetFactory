from pathlib import Path
from PIL import Image
import json
H=Path(__file__).resolve().parent;R=H.parents[4];folder=R/'.validation/animation_showcase/hybrid_jump_original_v002/preview_frames'
paths=sorted(folder.glob('*.png'));assert len(paths)==72
sheet=Image.new('RGB',(1120,760*5))
for j,i in enumerate((0,20,32,39,47)):
 with Image.open(paths[i])as im:sheet.paste(im.convert('RGB'),(0,760*j))
palette=sheet.quantize(colors=128);frames=[]
for p in paths:
 with Image.open(p)as im:frames.append(im.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE))
out=H/'Jump_SoftBounce_v002_AB.gif';frames[0].save(out,save_all=True,append_images=frames[1:],duration=[30,30,40]*24,loop=0,optimize=False,disposal=2)
with Image.open(out)as im:
 encoded=im.n_frames;assert 2<=encoded<=72;total=0
 for i in range(im.n_frames):im.seek(i);total+=im.info['duration']
 assert total==2400
(H/'preview_metadata.json').write_text(json.dumps({'actual_blender_frames':72,'encoded_frames':encoded,'identical_holds_merged_by_codec':True,'duration_ms':total,'average_sample_fps':30,'interpolated_frames':False,'source':'Saved original authoring Action plus separate preview elevation, same stage as central','bytes':out.stat().st_size},indent=2),encoding='utf8')
print('NORMAL_TIME_JUMP_GIF',out.stat().st_size,total)
