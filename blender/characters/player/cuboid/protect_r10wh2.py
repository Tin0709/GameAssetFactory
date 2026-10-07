from pathlib import Path
import subprocess,hashlib,json
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory');OUT=ROOT/'blender/characters/player/cuboid/weapon_hold_r10wh2_review';OUT.mkdir(exist_ok=True)
assert not (OUT/'protected_files.json').exists()
names=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
rows={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names if n and (ROOT/n).is_file()}
(OUT/'protected_files.json').write_text(json.dumps(rows,indent=2));print(json.dumps({'protected_files':len(rows)}))
