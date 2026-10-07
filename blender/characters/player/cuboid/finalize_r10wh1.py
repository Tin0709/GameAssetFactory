"""Deliver exact live Blender checkpoint; protect every original file."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory').resolve()
BASE=ROOT/'blender/characters/player/cuboid';OUT=BASE/'weapon_hold_r10wh1_review'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['validation.json','review_validation.json','camera_validation.json','media_validation.json','file_preservation.json']:
    assert json.loads((OUT/name).read_text())['passed'],name
d=json.loads((OUT/'checkpoint.json').read_text());source=Path(d['checkpoint']).resolve()
target=BASE/'player_weapon_hold_r10wh1_study.blend'
assert source.parent==OUT.resolve() and source.name.startswith('checkpoint_')
assert Path(d['target']).resolve()==target.resolve()
protected=json.loads((OUT/'protected_files.json').read_text())
assert target.relative_to(ROOT).as_posix() not in protected
shutil.copyfile(source,target);assert sha(source)==sha(target)
changed=[n for n,h in protected.items() if not (ROOT/n).is_file() or sha(ROOT/n)!=h]
assert not changed,changed
result={'passed':True,'target':str(target),'checkpoint':str(source),'sha256':sha(target),
        'size_bytes':target.stat().st_size,'protected_files':len(protected),'changed':changed}
(OUT/'final_save.json').write_text(json.dumps(result,indent=2))
owned=[p for p in BASE.glob('*r10wh1*') if p.is_file()]+[p for p in OUT.iterdir() if p.is_file() and p.suffix!='.blend' and p.name!='manifest.json']
manifest={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in owned}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(result))
