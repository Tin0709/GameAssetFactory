"""Copy the live-saved checkpoint to the owned study and verify exact bytes."""
from pathlib import Path
import hashlib, json, shutil
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory')
BASE=ROOT/'blender/characters/player/cuboid';OUT=BASE/'living_r9w4_review'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['validation','review_validation','motion_validation','camera_validation','media_validation','file_preservation']:
    evidence=json.loads((OUT/(name+'.json')).read_text());assert evidence['passed'],name
media=json.loads((OUT/'media_validation.json').read_text())
assert media['required_movies']==13 and len(media['movies'])==13
for row in media['movies'].values():assert sha(OUT/row['file'])==row['sha256'],row['file']
record=json.loads((OUT/'checkpoint.json').read_text());source=Path(record['checkpoint']).resolve();target=Path(record['target']).resolve()
assert source.parent==OUT.resolve() and source.name.startswith('checkpoint_') and source.suffix=='.blend',source
assert target== (BASE/'player_weapon_onearm_r9w4_study.blend').resolve(),target
assert source!=target and source.stat().st_size>1_000_000
source_sha=sha(source);shutil.copyfile(source,target);target_sha=sha(target);assert source_sha==target_sha
result={'passed':True,'live_checkpoint':str(source),'study':str(target),'sha256':target_sha,'bytes':target.stat().st_size,'review':json.loads((OUT/'review_state.json').read_text())}
(OUT/'final_save.json').write_text(json.dumps(result,indent=2))
files=list(BASE.glob('*r9w4*.py'))+[target]+[p for p in OUT.iterdir() if p.is_file() and not p.name.startswith('checkpoint_') and p.name!='manifest.json']
manifest={str(p.relative_to(ROOT)).replace('\\','/'):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(files)}
(OUT/'manifest.json').write_text(json.dumps({'files':manifest,'temporary_live_checkpoints_excluded':True},indent=2))
print(json.dumps({'passed':True,'study':str(target),'bytes':result['bytes'],'sha256':target_sha,'manifest_files':len(files),'scene':result['review']['scene'],'frame':result['review']['frame']}))
