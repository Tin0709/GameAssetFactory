from pathlib import Path
OUT=Path(__file__).resolve().parent/'turning_study_r3_review';p=OUT/'index.html';s=p.read_text(encoding='utf-8')
for gait in ['walk','sprint']:
 anchor=f'<img src="{gait}_circle_sequence.jpg">'
 if f'{gait}_detail_sequence.jpg' not in s:
  assert anchor in s;s=s.replace(anchor,f'<img src="{gait}_detail_sequence.jpg"><p>Detail crops share scale within each A/B pair; use the movie to judge travel.</p>'+anchor)
p.write_text(s,encoding='utf-8');print('R3_PAGE_FINALIZED')
