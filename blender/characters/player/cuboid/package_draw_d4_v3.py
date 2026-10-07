from PIL import Image,ImageDraw
from pathlib import Path
BASE=Path(__file__).parent;out=BASE/'draw_d4_v3_review'
cases=[(3,'None',0),(2,'None',0),(3,'Idle',0)]+[(3,'Run',p) for p in [0,4,8,12]]
for v,layer,p in cases:
 frames=[Image.open(out/f'v{v}_{layer}_{p}_{i:02d}.png').convert('RGB') for i in range(27)]
 # Playback at authoring rate: half-frame samples, 13-frame duration.
 frames[0].save(out/f'v{v}_{layer}_{p}.gif',save_all=True,append_images=frames[1:],duration=[20,20,20,20,20,20,20,20,30]*3,loop=0)
 sheet=Image.new('RGB',(7*192,4*212),(24,27,30));draw=ImageDraw.Draw(sheet)
 for i,img in enumerate(frames):
  x=(i%7)*192;y=(i//7)*212;sheet.paste(img.resize((192,192)),(x,y));draw.text((x+5,y+194),f'{layer} {p*6.25:g}% f{1+i*.5:g}',fill='white')
 sheet.save(out/f'v{v}_{layer}_{p}_sheet.jpg',quality=92)
compare=Image.new('RGB',(768,384))
imgs=[]
for i in range(27):
 img=compare.copy()
 for col,v in enumerate([2,3]):
  img.paste(Image.open(out/f'v{v}_None_0_{i:02d}.png').convert('RGB'),(384*col,0))
  ImageDraw.Draw(img).text((384*col+10,10),f'Draw V{v}   f{1+i*.5:g}',fill='white')
 imgs.append(img)
imgs[0].save(out/'V2_vs_V3.gif',save_all=True,append_images=imgs[1:],duration=[20,20,20,20,20,20,20,20,30]*3,loop=0)
print('Seven preview GIFs, contact sheets and V2/V3 comparison created.')
