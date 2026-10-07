"""Check deliverable completeness and JS syntax without browser navigation."""
import json,re,subprocess
from pathlib import Path
from PIL import Image
OUT=Path(__file__).resolve().parents[3]/'.validation/locomotion_r5'
total=0
for folder in ['rendered','rendered_best']:
 metrics=json.loads((OUT/folder/'metrics.json').read_text())
 for label,rows in metrics.items():
  for index,row in enumerate(rows):
   path=OUT/folder/f'{label}_{index:03}.jpg'
   with Image.open(path) as im:assert im.size==(3840,720),(path,im.size)
   assert abs(row['t']-index/24)<1e-10
   total+=1
 assert len(metrics)==12
a=json.loads((OUT/'rendered/metrics.json').read_text());b=json.loads((OUT/'rendered_best/metrics.json').read_text())
assert all(x[k]==y[k] for n in a for x,y in zip(a[n],b[n]) for k in ['phase','speed','yaw','command_rate','B','C'])
page=(OUT/'review/index.html').read_text(encoding='utf-8')
js=re.search(r'<script>(.*?)</script>',page,re.S).group(1)
(OUT/'review/check_syntax.js').write_text(js,encoding='utf-8')
subprocess.run(['node','--check',str(OUT/'review/check_syntax.js')],check=True)
for name in ['runtime_validation.json','import_validation.json']:
 assert json.loads((OUT/name).read_text())['passed']
for name in ['capture_best.log','validation.log','import_validation.log','open_review_live.log']:
 assert 'ERROR' not in (OUT/name).read_text(encoding='utf-8'),name
assert 'R5_LEFT_OPEN_C' in (OUT/'open_review_live.log').read_text(encoding='utf-8')
result={'passed':True,'captured_ABC_triplets':total,'paths_per_stage':12,'render_stage_movement_phase_weights_exact_match':True,'review_JS_syntax_valid':True,'browser_UI_verified':False,'browser_limitation':'Local-file navigation blocked by browser tool policy; no workaround attempted.'}
(OUT/'review_verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
