import json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[3]/'.validation/locomotion_r5';tag=sys.argv[1] if len(sys.argv)>1 else 'baseline';p=json.loads((OUT/(tag+'_summary.json')).read_text());fail=[]
for g in ['Walk','Sprint']:
 if p[g+'_TightCircle']['sustained_mean_abs_final']<.95:fail.append(g+' tight circle does not expose near-full authored turn')
 if p[g+'_MildLeft']['peak_final']>.4:fail.append(g+' mild bend too strong')
 if p[g+'_TightCircle']['recovery_seconds_below_0_05']>.6:fail.append(g+' recovery too slow')
if p['Sprint_DefaultCircle']['sustained_mean_abs_final']<.75:fail.append('Default Sprint circle remains under-driven')
print(tag,fail or 'R5_RESPONSE_CHECKS_PASS');sys.exit(bool(fail))
