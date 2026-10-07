"""Contact sheets from unmodified gameplay-camera renders; crops are labelled."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]/'.validation/draw_d5'
steps=['00','12','20','22','30','38','44','50','58','64','65','exit']
for weapon in [1,2]:
    sheet=Image.new('RGB',(12*260,5*280),(24,28,33));d=ImageDraw.Draw(sheet)
    for row,phase in enumerate(['-1_0','0_0','0_25','0_5','0_75']):
        for col,step in enumerate(steps):
            p=ROOT/f'{weapon}_{phase}_{step}.png'
            im=Image.open(p).crop((485,280,650,440)).resize((247,240))
            sheet.paste(im,(col*260,row*280+32))
            d.text((col*260+5,row*280+7),f'{"M4" if weapon==1 else "Shotgun"} phase {phase} / {step}',fill='white')
    sheet.save(ROOT/f'weapon_{weapon}_gameplay_crops.jpg')
