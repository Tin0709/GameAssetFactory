import bpy,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE));import gaf_weapon_library as lib
lib.register();bpy.ops.wm.open_mainfile(filepath=str(HERE/'Weapon_Showcase.blend'))
s=bpy.context.scene;s.render.threads_mode='FIXED';s.render.threads=8;s.cycles.samples=24
OUT=HERE.parent/'rifle_stylized_v2/review';OUT.mkdir(parents=True,exist_ok=True)
for entry,mode,direction,name in [('rifle_stylized_v2','STANDALONE','THREE_QUARTER','rifle_v2_threequarter'),('rifle_stylized_v2','STANDALONE','RIGHT','rifle_v2_side'),('rifle_production_r13','READY','THREE_QUARTER','original_ready'),('rifle_stylized_v2','READY','THREE_QUARTER','rifle_v2_ready'),('rifle_stylized_v2','READY','RIGHT','rifle_v2_ready_side'),('rifle_stylized_v2','HOLSTER','BACK','rifle_v2_holster'),('rifle_production_r13','HOLSTER','BACK','original_holster')]:
 s.gaf_weapon_index=next(i for i,e in enumerate(lib.entries(s)) if e['id']==entry);s.gaf_fit_mode=mode;lib.activate(s);lib.view(s,direction)
 s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);print('RENDERED',name,flush=True)
