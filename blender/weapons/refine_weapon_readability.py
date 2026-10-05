"""Local readability refinements based on the preserved construction source.
Keeps the validated structural cleanup; writes only new revisions.
"""
from pathlib import Path
import hashlib
base=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
current={'Pistol':'pistol/blocky_pistol_v2.blend','M4A1':'m4a1_blocky/m4a1_blocky_v3.blend','Shotgun':'shotgun/blocky_shotgun_v2.blend'}
current_hash={f:hashlib.sha256((base/f).read_bytes()).hexdigest() for f in current.values()}
for f in ['pistol/blocky_pistol_v3.blend','m4a1_blocky/m4a1_blocky_v4.blend','shotgun/blocky_shotgun_v3.blend']:
 if (base/f).exists():raise RuntimeError('New revision already exists: '+f)
source=(base/'cleanup_weapon_geometry.py').read_text(encoding='utf-8-sig')
source=source.replace("'blocky_pistol_v2'","'blocky_pistol_v3'").replace("'m4a1_blocky_v3'","'m4a1_blocky_v4'").replace("'blocky_shotgun_v2'","'blocky_shotgun_v3'")
source=source.replace("[(-.023,.094),(.047,.067),(.038,.039),(.009,-.055),(.012,-.064),(.012,-.072),(-.038,-.072),(-.038,-.059),(-.026,-.034)]","[(-.038,.081),(-.025,.094),(.027,.071),(.027,-.072),(-.038,-.072)]")
source=source.replace('],.031077588,6,14)','],.036,6,14)').replace('],.031,6,14)','],.036,6,14)')
source=source.replace("item={'before_triangles':before", "before={'Pistol':352,'M4A1':760,'Shotgun':670}[key]\n item={'before_triangles':before")
source=source.replace('weapon_cleanup_report.json','weapon_refinement_report.json')
exec(compile(source,'refine_weapon_readability_generated.py','exec'))
assert all(hashlib.sha256((base/f).read_bytes()).hexdigest()==h for f,h in current_hash.items())
