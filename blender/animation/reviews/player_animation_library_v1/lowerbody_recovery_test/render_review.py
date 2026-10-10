import bpy,runpy,sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
B=runpy.run_path(str(OUT/'build_test.py'))
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
frames=[1,7,10,13,18,22,33,42] if 'keys' in args else range(1,B['END']+1)
for view in ['FRONT','THREE_QUARTER','SIDE']:
    missing=[f for f in frames if not (OUT/'frames'/view.lower()/f'{f:03d}.png').exists()]
    print('RENDER REVIEW',view,missing,flush=True)
    if missing:B['render'](view,missing)
print('REVIEW RENDERS COMPLETE',flush=True)
