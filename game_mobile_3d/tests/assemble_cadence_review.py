from pathlib import Path
from PIL import Image,ImageDraw
p=Path(__file__).parent;frames=[]
for i in range(20):
 canvas=Image.new('RGB',(960,540))
 for j,s in enumerate([100,160,194]):
  im=Image.open(p/f'cadence_{s:03d}_{i:02d}.png').convert('RGB').resize((480,270))
  canvas.paste(im,((j%2)*480,(j//2)*270))
  ImageDraw.Draw(canvas).text(((j%2)*480+8,(j//2)*270+8),f'{s/100:.2f}x - actual gameplay camera',fill='white',stroke_width=1,stroke_fill='black')
 frames.append(canvas)
frames[0].save(p/'run_cadence_comparison.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
frames[8].save(p/'run_cadence_comparison.png')
