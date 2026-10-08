from pathlib import Path
import json
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent
frames=[18,21,25,28,32,36,65,69,75,80,85,91]
labels={18:'UP preparation',21:'UP rising',25:'UP clearance',28:'UP apex',32:'UP landing approach',36:'UP recovery',65:'DOWN preparation',69:'DOWN edge unload',75:'DOWN shoes clear / fall',80:'DOWN landing approach',85:'DOWN contact / recovery',91:'RUN OUT'}
for camera,stem in [('Gameplay_Oblique_FIXED','gameplay_contact_sheet'),('Side_Diagnostic_FIXED','side_contact_sheet')]:
    w,h=480,294;sheet=Image.new('RGB',(w*3,h*4),(20,24,30));d=ImageDraw.Draw(sheet)
    for i,f in enumerate(frames):
        im=Image.open(OUT/'.validation'/camera/f'{f:04d}.png').convert('RGB');im.thumbnail((480,270));x=(i%3)*w;y=(i//3)*h;sheet.paste(im,(x,y));d.text((x+10,y+274),f'f{f:03d}  {(f-1)/24:.3f}s  {labels[f]}',fill=(235,239,242))
    sheet.save(OUT/(stem+'.jpg'),quality=92)
print('CONTACT_SHEETS_SAVED')
# Consolidate only this study's generated reference diagnostics, preserving input video.
raw=OUT/'.validation/reference_frames';raw.mkdir(parents=True,exist_ok=True)
legacy=OUT/'.validation/reference_legacy';legacy.mkdir(parents=True,exist_ok=True)
for p in OUT.glob('reference_f*.png'):
    assert p.resolve().parent==OUT.resolve();p.replace(raw/p.name)
for name in ['reference_detail.jpg','reference_detail.json']+[f'reference_detail_{i:02d}.jpg' for i in range(5)]:
    p=OUT/name
    if p.exists():p.replace(legacy/p.name)
obsfile=OUT/'reference_observations.json';obs=json.loads(obsfile.read_text())
proposal=obs['authoring_proposal_not_source_measurement']
proposal.pop('up_initial_timing',None);proposal.pop('down_initial_timing',None)
proposal['authored_study_timing_global_frames_24fps']={'up_prep':[17,18],'up_flight':[19,33],'up_recovery':[33,38],'down_edge_unload':[67,73],'down_fall':[74,85],'down_recovery':[85,91]}
proposal['approval_status']='PENDING USER REVIEW; timing is authored proposal, not source measurement'
obsfile.write_text(json.dumps(obs,indent=2))
