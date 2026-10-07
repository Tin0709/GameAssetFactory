"""Safe R6 production copies; use the already validated sampling pipeline."""
from pathlib import Path
BASE=Path(__file__).resolve().parent
code=(BASE/'export_locomotion_r4g.py').read_text().replace('player_locomotion_turning_v2_study.blend','player_locomotion_turning_v3_study.blend').replace('export/locomotion_r4g','export/locomotion_r6p').replace('_Reference_V2','_Reference_V3').replace('R4G_EXPORT','R6P_EXPORT')
exec(compile(code,str(__file__),'exec'))
