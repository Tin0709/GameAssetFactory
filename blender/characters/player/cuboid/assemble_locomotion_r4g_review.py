"""Package actual Godot A/B captures at normal 24fps, with transparent measurement limits."""
from pathlib import Path
import json, numpy as np
from PIL import Image, ImageDraw, ImageFont
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
SOURCE=ROOT/'game_mobile_3d/.validation/locomotion_r4g/rendered'
OUT=ROOT/'game_mobile_3d/.validation/locomotion_r4g/review';OUT.mkdir(parents=True,exist_ok=True)
metrics=json.loads((SOURCE/'measurements.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
summary={}
for label,m in metrics.items():
    frames=[]
    for i in range(72):
        sheet=Image.new('RGB',(1120,380),'#10202a');draw=ImageDraw.Draw(sheet)
        draw.text((12,7),f'{label} · {m["speed_m_s"]:.2f} m/s · turn {m["turn_samples"][i]:+.3f} · 24 fps · AWAITING HUMAN REVIEW',font=small,fill='white')
        for col,mode in enumerate(['A','B']):
            im=Image.open(SOURCE/f'{label}_{mode}_{i:03d}.png').convert('RGB')
            # Enlarged crop of the primary fixed-axis gameplay camera; no fabricated orbit.
            im=im.crop((240,180,720,460)).resize((560,327),Image.Resampling.LANCZOS)
            sheet.paste(im,(col*560,53))
            draw.text((col*560+12,29),'A — PATH / FACING ONLY' if mode=='A' else 'B — TURNING POSE BLEND',font=small,fill='white')
        frames.append(sheet)
    # 41/42/42ms keeps each three-frame group at125ms, exactly24fps on average.
    frames[0].save(OUT/f'{label}_AB_24fps.gif',save_all=True,append_images=frames[1:],duration=[41,42,42]*24,loop=0,optimize=True)
    contact=Image.new('RGB',(1120,1140),'#10202a')
    for row,i in enumerate([5,29,53]):contact.paste(frames[i],(0,row*380))
    contact.save(OUT/f'{label}_phases.png')
    full=Image.new('RGB',(1440,540))
    for row,mode in enumerate(['A','B']):
        for col,i in enumerate([5,29,53]):
            full.paste(Image.open(SOURCE/f'{label}_{mode}_{i:03d}.png').resize((480,270)),(col*480,row*270))
    full.save(OUT/f'{label}_gameplay_camera.png')
    sm={'speed_m_s':m['speed_m_s'],'measured_travel_speed_range_m_s':[min(m['measured_travel_speed_m_s']),max(m['measured_travel_speed_m_s'])],'radius_m':m['radius_m'],'turn_range':[min(m['turn_samples']),max(m['turn_samples'])],'A':{},'B':{}}
    for mode in ['A','B']:
        for leg,v in m[mode].items():
            speeds=v['contact_speed_m_s']; heights=v['height_m']
            sm[mode][leg]={'contact_intervals':len(speeds),'mean_horizontal_sole_speed_m_s':float(np.mean(speeds)) if speeds else None,'median_horizontal_sole_speed_m_s':float(np.median(speeds)) if speeds else None,'sole_low_height_range_m':[min(heights),max(heights)]}
    summary[label]=sm
(OUT/'foot_observations.json').write_text(json.dumps(summary,indent=2))
for name,m in summary.items():
    print(name,'turn',m['turn_range'],'A',[round(v['mean_horizontal_sole_speed_m_s'],3) if v['mean_horizontal_sole_speed_m_s'] else None for v in m['A'].values()],'B',[round(v['mean_horizontal_sole_speed_m_s'],3) if v['mean_horizontal_sole_speed_m_s'] else None for v in m['B'].values()])
print('R4G_REVIEW_PACKAGED',len(summary),'normal-speed A/B comparisons')
