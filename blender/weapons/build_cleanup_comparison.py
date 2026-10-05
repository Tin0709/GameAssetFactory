import bpy,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
reports=json.loads((BASE/'weapon_cleanup_report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(BASE/'m4a1_blocky/m4a1_blocky_v1.blend'))
scene=bpy.context.scene
source=(BASE/'build_weapon_family_v1.py').read_text(encoding='utf-8-sig')
code=source[source.index("compare=bpy.data.scenes.new('Weapon_Family_Comparison')"):]
code=code.replace('Weapon_Family_Comparison','Weapon_Cleanup_Comparison').replace('weapon_family_comparison','weapon_cleanup_comparison').replace('weapon_family_report.json','weapon_cleanup_report.json')
exec(code)
