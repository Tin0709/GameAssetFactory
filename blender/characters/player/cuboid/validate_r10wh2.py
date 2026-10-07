"""Verify new study availability, then dense hold and preservation integrity."""
import bpy,json,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'weapon_hold_r10wh2_review';sys.path.insert(0,str(BASE))
expected=[p+m+'_ElbowStudy_V2' for p in ['LongGun','Shotgun','Pistol'] for m in ['Hold','Move','AimAround']]
missing=[n for n in expected if n not in bpy.data.actions]
if missing:
    result={'passed':False,'missing':missing,'reason':'New elbow studies not authored'}
    (OUT/'contract_red.json').write_text(json.dumps(result,indent=2))
else:
    from hold_r10wh2_common import validate
    result=validate();(OUT/'validation.json').write_text(json.dumps(result,indent=2))
