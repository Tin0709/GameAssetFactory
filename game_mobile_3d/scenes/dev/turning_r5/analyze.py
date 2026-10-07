import json
from pathlib import Path
OUT=Path(__file__).resolve().parents[3]/'.validation/locomotion_r5'
baseline=json.loads((OUT/'baseline_samples.json').read_text())
recheck=json.loads((OUT/'original_recheck_samples.json').read_text())
candidate=json.loads((OUT/'candidate_samples.json').read_text())
assert all(a[k]==b[k] for n in baseline for a,b in zip(baseline[n],recheck[n]) for k in a),'B regression'
result={'original_B_trace_exactly_preserved':True,'cases':{},'reversal':{}}
for name,rows in candidate.items():
 b=baseline[name]
 result['cases'][name]={}
 for tag,seq in [('B',b),('C_mapping',rows)]:
  active=[r for r in seq if 1<=r['t']<6];sustained=[r for r in seq if 2<=r['t']<6]
  result['cases'][name][tag]={'raw_yaw_peak_rad_s':max(abs(r['raw_yaw_rate']) for r in active),'normalized_peak':max(abs(r['normalized_before_smoothing']) for r in active),'final_peak':max(abs(r['final_blend']) for r in active),'sustained_abs_mean':sum(abs(r['final_blend']) for r in sustained)/len(sustained),'seconds_to_0_8':next((r['t']-1 for r in active if abs(r['final_blend'])>=.8),None),'seconds_to_0_9':next((r['t']-1 for r in active if abs(r['final_blend'])>=.9),None),'recovery_to_0_05_s':next((r['t']-6 for r in seq if r['t']>=6 and abs(r['final_blend'])<.05),None)}
 if 'Reversal' in name:
  opposite=[r for r in rows if 3.5<=r['t']<6]
  result['reversal'][name]={'zero_cross_after_command_s':next(r['t']-3.5 for r in opposite if r['final_blend']>0),'opposite_0_8_after_command_s':next(r['t']-3.5 for r in opposite if r['final_blend']>=.8),'max_weight_step_at_60Hz':max(abs(a['final_blend']-b['final_blend']) for a,b in zip(rows,rows[1:])),'samples_in_neutral_band_0_02':sum(abs(r['final_blend'])<.02 for r in opposite)}
(OUT/'comparison_summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result['reversal'],indent=2));print('B_ORIGINAL_TRACE_EXACT_MATCH')
