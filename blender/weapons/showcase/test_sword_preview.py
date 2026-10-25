"""Actual saved-library transitions between firearm fits and standalone sword."""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import gaf_weapon_library as lib
lib.register()
bpy.ops.wm.open_mainfile(filepath=str(HERE/'Weapon_Showcase.blend'))
s=bpy.context.scene;spec=lib.entries(s)
sword=next((i for i,e in enumerate(spec) if e['kind']=='Sword'),None)
assert sword is not None,'Sword has not been registered in the existing library'
assert spec[sword]['preview_modes']==['STANDALONE']
checks=0
for i,e in enumerate(spec):
    if e['kind'] not in ['Rifle','Pistol','Shotgun']:continue
    for mode in ['READY','HOLSTER']:
        s.gaf_weapon_index=i;s.gaf_fit_mode=mode;lib.activate(s)
        assert s.gaf_fit_mode==mode
        assert any(c.get('fit_kind')==e['kind'] and c.get('fit_mode')==mode and not c.hide_render for c in bpy.data.collections)
        s.gaf_weapon_index=sword;lib.activate(s)
        assert s.gaf_fit_mode=='STANDALONE'
        assert not any(c.get('fit_kind') and not c.hide_render for c in bpy.data.collections)
        root=lib.root_of(spec[sword])
        assert max(abs(root.matrix_world[i][j]-Matrix.Identity(4)[i][j]) for i in range(4) for j in range(4))<1e-6
        # Directly requesting an unavailable mode must also be harmless.
        s.gaf_fit_mode=mode;lib.activate(s);assert s.gaf_fit_mode=='STANDALONE'
        for direction in ['LEFT','RIGHT','FRONT','BACK','THREE_QUARTER']:lib.view(s,direction)
        s.gaf_weapon_index=i;s.gaf_fit_mode=mode;lib.activate(s)
        assert s.gaf_fit_mode==mode
        checks+=1
assert not bpy.data.actions
print('SWORD_PREVIEW_TRANSITIONS_PASSED',checks)
