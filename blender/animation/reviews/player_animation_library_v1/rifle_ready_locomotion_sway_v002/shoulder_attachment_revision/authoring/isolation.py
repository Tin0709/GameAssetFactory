import bpy,sys,json,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());O=Path(__file__).resolve().parent.parent;S=Path('/Users/tin/Documents/ChatGPT/New project/experiments/rifle_run_shoulders_20261018');sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
sp=importlib.util.spec_from_file_location('fp','/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_idle_source_v001/fingerprint.py');fp=importlib.util.module_from_spec(sp);sp.loader.exec_module(fp)
before=json.loads((S/'before/fingerprint.json').read_text());N='Rifle_Ready_Run_ActionsStyle_v002'
# Full old-Action signatures are checked in build.py; avoid repeating that
# expensive check here while independently checking all native asset data.
assert json.loads((O/'build_validation.json').read_text())['other_actions_exact']==86
original_sig=ui.action_signature
try:
 ui.action_signature=lambda a:None
 after=fp.fingerprint()
finally:ui.action_signature=original_sig
assert set(after['actions'])==set(before['actions'])
for k in before:
 if k not in ['actions','images']:assert after[k]==before[k],k
# Saving the separate source container remaps image path strings. Compare
# packed image bytes, dimensions and color spaces independently of paths.
image_data={i.name:{'size':list(i.size),'colorspace':i.colorspace_settings.name,'packed_sha256':[hashlib.sha256(bytes(f.packed_file.data)).hexdigest() for f in i.packed_files]} for i in bpy.data.images}
assert image_data==json.loads((S/'before/image_content.json').read_text()),'image pixels changed'
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;new=bpy.data.actions[N]
with bpy.data.libraries.load(str(S/'before/study.blend'),link=False) as (src,dst):dst.actions=[N]
old=dst.actions[0];old.name='_VALIDATION_BEFORE_PENDING_RUN';assert ui.action_signature(old)==before['actions'][N]
palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));core=[n for n in r.pose.bones.keys() if n not in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']]
metrics={'core_world_matrix_error':0.,'right_grip_relative_matrix_error':0.,'left_palm_relative_rifle_error_m':0.,'left_support_life_excursion_m':0.};ref=None
for f in [1,2701]+[1+j*63.6 for j in range(43)]:
 poses=[]
 for a in [old,new]:
  r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();poses.append({b.name:b.matrix.copy() for b in r.pose.bones})
 B,M=poses
 def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
 for n in core:metrics['core_world_matrix_error']=max(metrics['core_world_matrix_error'],md(B[n],M[n]))
 for n in ['UpperArm.R','ForeArm.R']:metrics['right_grip_relative_matrix_error']=max(metrics['right_grip_relative_matrix_error'],md(B['WeaponCarrier'].inverted()@B[n],M['WeaponCarrier'].inverted()@M[n]))
 bp=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm);np=M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm)
 metrics['left_palm_relative_rifle_error_m']=max(metrics['left_palm_relative_rifle_error_m'],(bp-np).length)
 if ref is None:ref=np.copy()
 metrics['left_support_life_excursion_m']=max(metrics['left_support_life_excursion_m'],(np-ref).length)
assert metrics['core_world_matrix_error']<1e-6;assert metrics['right_grip_relative_matrix_error']<1e-5;assert metrics['left_palm_relative_rifle_error_m']<1e-5
bpy.data.actions.remove(old)
protected=json.loads((S/'before/protected.json').read_text());assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in protected.items())
report={'passed':True,'other_actions_exact':len(before['actions'])-1,'native_asset_content_exact':True,'source_image_path_note':'Only path strings remapped while saving the separate authoring container; packed pixels, dimensions and color spaces are exact. Native Showcase image paths are not changed.','paired_evaluated_poses':45,'metrics':metrics,'godot_and_parent_study_files_unchanged':len(protected)};(O/'isolation_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
