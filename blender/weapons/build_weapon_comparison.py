import bpy,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
reports={k:json.loads((BASE/f).read_text()) for k,f in [('M4A1','m4a1_blocky/m4a1_blocky_v2_report.json'),('Pistol','pistol/blocky_pistol_v1_report.json'),('Shotgun','shotgun/blocky_shotgun_v1_report.json')]}
reports['M4A1']['width_reduction_percent']=(1-.103/.116)*100
reports['Shotgun']['pump_translation_blender_m']=[0,.356,.131]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'m4a1_blocky/m4a1_blocky_v1.blend'))
scene=bpy.context.scene
source=(BASE/'build_weapon_family_v1.py').read_text(encoding='utf-8-sig')
exec(source[source.index("compare=bpy.data.scenes.new('Weapon_Family_Comparison')"):])
