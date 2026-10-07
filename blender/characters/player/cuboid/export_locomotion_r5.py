"""Apply the validated R4 export pipeline to V3 copies in a separate export folder."""
from pathlib import Path
BASE=Path(__file__).resolve().parent
code=(BASE/'export_locomotion_r4g.py').read_text()
code=code.replace('player_locomotion_turning_v2_study.blend','player_locomotion_turning_v3_study.blend').replace('export/locomotion_r4g','export/locomotion_r5').replace('_Reference_V2','_Reference_V3').replace('R4G_EXPORT','R5_EXPORT')
exec(compile(code,str(BASE/'export_locomotion_r5.py'),'exec'))
