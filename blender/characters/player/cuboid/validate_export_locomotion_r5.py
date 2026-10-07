"""Independent Blender-to-GLB matrix checks; separate lab-only V3 output."""
from pathlib import Path
BASE=Path(__file__).resolve().parent
code=(BASE/'validate_export_locomotion_r4g.py').read_text().replace('export/locomotion_r4g','export/locomotion_r5').replace('player_cuboid_locomotion_v2_test.glb','player_cuboid_locomotion_v3_test.glb').replace('player_locomotion_turning_v2_study.blend','player_locomotion_turning_v3_study.blend')
exec(compile(code,str(BASE/'validate_export_locomotion_r5.py'),'exec'))
