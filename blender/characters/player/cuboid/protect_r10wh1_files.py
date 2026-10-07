from pathlib import Path
import subprocess,hashlib,json,shutil
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory');OUT=ROOT/'blender/characters/player/cuboid/weapon_hold_r10wh1_review';OUT.mkdir(exist_ok=True)
names=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0');rows={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names if n and (ROOT/n).is_file()}
(OUT/'protected_files.json').write_text(json.dumps(rows,indent=2))
for src,name in [(r'C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-59adc61c-0b9e-4405-8fa0-ae09de8a7e34.webp','reference_1.webp'),(r'C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-8cbcc3d0-e392-4836-b16d-16b9e5561f57.jpg','reference_2.jpg')]:shutil.copyfile(src,OUT/name)
print(json.dumps({'protected_files':len(rows),'references':2}))
