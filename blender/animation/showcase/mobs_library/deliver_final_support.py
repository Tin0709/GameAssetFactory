from pathlib import Path
import shutil,json,hashlib
HERE=Path(__file__).resolve().parent
SUPPORT=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/mobs_library')
private=SUPPORT/'research/actions_stuff_zombie_v001'
before=hashlib.sha256((SUPPORT.parent/'Mobs_Animation_Library.blend').read_bytes()).hexdigest()
for p in HERE.glob('*.py'):
    if p.name not in ['install_library.py','update_support.py']:shutil.copy2(p,SUPPORT/p.name)
for pattern in ['validation_*.json','*.md','*.command']:
    for p in HERE.glob(pattern):shutil.copy2(p,SUPPORT/p.name)
(SUPPORT/'Open_Mobs_Animation_Library.command').chmod(0o755)
for p in (HERE/'source_research').iterdir():
    if p.suffix in ['.py','.json','.blend','.md']:shutil.copy2(p,private/p.name)
shutil.copytree(HERE/'source_research/review',private/'review',dirs_exist_ok=True)
shutil.copytree(HERE/'review',SUPPORT/'review',dirs_exist_ok=True)
shutil.copy2(HERE/'gaf_mobs_animation_library.py',Path(json.loads((HERE/'installation.json').read_text())['addon']))
assert before==hashlib.sha256((SUPPORT.parent/'Mobs_Animation_Library.blend').read_bytes()).hexdigest()
print('FINAL_SUPPORT_AND_MEDIA_DELIVERED; LIBRARY_UNCHANGED',before)
