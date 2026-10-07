"""Record/check tracked assets outside the two authorized lab scripts."""
import subprocess,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];OUT=ROOT/'game_mobile_3d/.validation/locomotion_r5';OUT.mkdir(parents=True,exist_ok=True)
allowed={'game_mobile_3d/scenes/dev/locomotion_lab_actor.gd','game_mobile_3d/scenes/dev/locomotion_turning_lab.gd'}
if '--check' in sys.argv:
 data=json.loads((OUT/'preservation.json').read_text());bad=[n for n,h in data.items() if not (ROOT/n).exists() or hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h];assert not bad,bad;print('R5_PRESERVED',len(data),'tracked files')
else:
 files=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0');data={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in files if n and n not in allowed and (ROOT/n).is_file()};(OUT/'preservation.json').write_text(json.dumps(data,indent=2));print('R5_BASELINE',len(data))
