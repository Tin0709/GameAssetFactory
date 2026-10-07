import json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[3]/'.validation/locomotion_r5'
tag=sys.argv[1] if len(sys.argv)>1 else 'baseline'
p=json.loads((OUT/(tag+'_samples.json')).read_text());out={}
for name,rows in p.items():
 active=[r for r in rows if 1<=r['t']<6];steady=[r for r in rows if 2<=r['t']<6]
 out[name]={'peak_raw_yaw_rad_s':max(abs(r['raw_yaw_rate']) for r in active),'peak_normalized':max(abs(r['normalized_before_smoothing']) for r in active),'peak_final':max(abs(r['final_blend']) for r in active),'sustained_mean_abs_final':sum(abs(r['final_blend']) for r in steady)/len(steady),'approaches_pure_0_9':any(abs(r['final_blend'])>=.9 for r in active),'seconds_to_0_8':next((r['t']-1 for r in active if abs(r['final_blend'])>=.8),None),'recovery_seconds_below_0_05':next((r['t']-6 for r in rows if r['t']>=6 and abs(r['final_blend'])<.05),None),'actual_speed_min_max':[min(r['measured_speed'] for r in rows),max(r['measured_speed'] for r in rows)]}
(OUT/(tag+'_summary.json')).write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
