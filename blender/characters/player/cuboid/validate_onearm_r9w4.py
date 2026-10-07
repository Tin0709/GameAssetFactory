"""Study contract: one supporting arm, separated off arm, original data preserved."""
from living_r9w2_common import *
OUT=BASE/'living_r9w4_review';failures=[]
names=[f'{prefix}{suffix}_OneArmStudy_V1' for prefix in ['LongGun','Pistol','Shotgun'] for suffix in ['Hold','Move','AimAround']]
missing=[n for n in names if n not in bpy.data.actions]
if missing:
    result={'passed':False,'failures':['New one-arm hold Actions missing'],'missing':missing}
    (OUT/'contract_red.json').write_text(json.dumps(result,indent=2))
else:
    from onearm_r9w4_common import validate_all
    result=validate_all()
    (OUT/'validation.json').write_text(json.dumps(result,indent=2))
