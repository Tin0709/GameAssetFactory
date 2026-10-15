import sys
from pathlib import Path
p=Path(__file__).with_name('render_video.py')
for view in ['THREE_QUARTER','FRONT','SIDE']:
 sys.argv=['blender','--',view]
 exec(compile(p.read_text(),str(p),'exec'))
