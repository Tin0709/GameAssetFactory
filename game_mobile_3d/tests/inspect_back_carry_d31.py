"""Reuse D2's triangle/box SAT on D3.1 stowed and transition samples."""
import ast,json
from pathlib import Path
import numpy as np
base=Path(__file__).parent
definitions=ast.parse((base/'inspect_holster_d2_collisions.py').read_text())
definitions.body=[n for n in definitions.body if isinstance(n,ast.FunctionDef)]
exec(compile(definitions,'D2_SAT','exec'))
data=json.loads((base/'back_carry_d31_collision_samples.json').read_text())
boxes=json.loads((base/'back_carry_d31_body_boxes.json').read_text())
weapon_tris={w:triangles(w) for w in [1,2]}
cases={}
for sample in data['samples']:
    case=cases.setdefault(sample['case'],{'samples':0,'head_hits':0,'deep_chest_hits':0,'arm_hits':0})
    case['samples']+=1
    for name,box in boxes.items():
        inverse=np.linalg.inv(sample['body'][name]);margin=.01 if name=='Head' else (.02 if name.startswith('Arm.') else .035)
        lo=np.array(box['min'])+margin;hi=np.array(box['max'])-margin
        hits=0
        for tris,matrix in zip(weapon_tris[sample['weapon']],sample['meshes']):
            transform=inverse@np.array(matrix)
            hits+=int(intersects(tris@transform[:3,:3].T+transform[:3,3],lo,hi).sum())
        case['head_hits' if name=='Head' else ('arm_hits' if name.startswith('Arm.') else 'deep_chest_hits')]+=hits
report={'cases':cases,'stowed_pass':all(not c['head_hits'] and not c['deep_chest_hits'] for n,c in cases.items() if 'holster' not in n),'transition_head_pass':all(not c['head_hits'] for c in cases.values()),'known_entry_chest_overlap':'Shotgun initial 0-0.0333 seconds unchanged D2 limitation'}
(base/'back_carry_d31_collision_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['stowed_pass'] and report['transition_head_pass']
