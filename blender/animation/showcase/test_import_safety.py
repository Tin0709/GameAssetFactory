"""Regression checks for reviewed future-import hazards; no files are saved."""
import bpy,json,copy
from pathlib import Path
import gaf_animation_library as ui
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[2]/'.validation/animation_showcase'
data=json.loads((OUT/'animation_manifest.json').read_text());s=bpy.context.scene
r=bpy.data.objects[ui.RIG];failures=[]
path=TMP/'safety_manifest.json';ui.manifest_path=lambda:path
for field,value in [('start',1.5),('end',17.5),('fps',29.97),('fps',100000),('fps_base',float('inf'))]:
    bad=copy.deepcopy(data);bad['animations'][0][field]=value;path.write_text(json.dumps(bad))
    try:ui.load_manifest()
    except ValueError:pass
    else:failures.append('invalid timing accepted: '+field+'='+str(value))
a=bpy.data.actions['Run_Expressive_Test'];c=ui.curves(a)[0];sig=ui.action_signature(a)
c.mute=not c.mute
if ui.action_signature(a)==sig:failures.append('mute change undetected')
c.mute=not c.mute
m=next(m for c in ui.curves(a) for m in c.modifiers);m.influence-=.1
if ui.action_signature(a)==sig:failures.append('modifier change undetected')
m.influence+=.1
bad=copy.deepcopy(data['animations'][0]);bad['rotation_modes']={b.name:b.rotation_mode for b in r.pose.bones};bad['rotation_modes']['Spine']='XYZ'
try:ui.validate_action(bpy.data.actions[bad['action']],bad,r)
except ValueError:pass
else:failures.append('rotation mode mismatch accepted')
assert not failures,failures
report={'passed':True,'invalid_timing_rejected':True,'evaluation_edits_detected':True,'rotation_modes_checked':True}
(OUT/'import_safety_verification.json').write_text(json.dumps(report,indent=2))
print('IMPORT SAFETY VERIFIED',json.dumps(report),flush=True)
