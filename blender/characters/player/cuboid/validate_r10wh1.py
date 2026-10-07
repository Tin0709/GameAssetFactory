"""R10-WH1 contract first: right-owned hold studies must exist before review."""
import bpy,json
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/weapon_hold_r10wh1_review');OUT.mkdir(exist_ok=True)
expected=[prefix+mode+'_RightEyeStudy_V1' for prefix in ['LongGun','Shotgun','Pistol'] for mode in ['Hold','Move','AimAround']]
missing=[n for n in expected if n not in bpy.data.actions]
if missing:
    result={'passed':False,'failures':['Missing right-hand/right-eye study actions'],'missing':missing}
    (OUT/'contract_red.json').write_text(json.dumps(result,indent=2))
else:
    from hold_r10wh1_common import validate_public
    result=validate_public();(OUT/'validation.json').write_text(json.dumps(result,indent=2))
