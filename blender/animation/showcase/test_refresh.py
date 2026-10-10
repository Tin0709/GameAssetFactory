"""Isolated fresh-process tests of refresh/import rejection and pending status."""
import bpy,json,hashlib,copy
from pathlib import Path
import gaf_animation_library as ui
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2];TMP=ROOT/'.validation/animation_showcase'
s=bpy.context.scene;original=json.loads((OUT/'animation_manifest.json').read_text())
temporary=TMP/'test_manifest.json';ui.manifest_path=lambda:temporary
def write(data):temporary.write_text(json.dumps(data))
def fingerprint():return [(a.name,ui.action_signature(a)) for a in bpy.data.actions]
def reject(data,message):
    before=fingerprint();selected=bpy.data.objects[ui.RIG].animation_data.action;count=len(s.gaf_clips)
    write(data)
    try:ui.refresh(s)
    except (ValueError,KeyError) as e:assert message in str(e),str(e)
    else:raise AssertionError('Invalid request was accepted')
    assert fingerprint()==before and bpy.data.objects[ui.RIG].animation_data.action==selected and len(s.gaf_clips)==count

data=copy.deepcopy(original);data['animations'].append(data['animations'][0]);reject(data,'unique')
data=copy.deepcopy(original);data['animations'][0]['source_sha256']='bad';reject(data,'Source missing or changed')
# Missing Action restored through the same selective import path the user will use.
bpy.data.actions.remove(bpy.data.actions['Expressive_Arm_Motion_Test']);write(original)
assert ui.refresh(s)==1 and len(bpy.data.actions)==3 and len(bpy.data.armatures)==1

def fixture(compatible):
    action=bpy.data.actions['Expressive_Arm_Motion_Test'].copy();action.name='Probe_Pending'
    arm=bpy.data.objects[ui.RIG].data.copy() if compatible else bpy.data.armatures.new('Incompatible_Probe')
    path=TMP/('compatible_source.blend' if compatible else 'incompatible_source.blend')
    e=copy.deepcopy(original['animations'][0]);e.update(action=action.name,source=path.relative_to(ROOT).as_posix(),source_armature=arm.name,action_sha256=ui.action_signature(action),status='pending',approval_note='Test fixture; not a real approved animation')
    bpy.data.libraries.write(str(path),{action,arm},fake_user=True)
    e['source_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    bpy.data.actions.remove(action);bpy.data.armatures.remove(arm)
    data=copy.deepcopy(original);data['animations'].append(e);return data

reject(fixture(False),'Incompatible source rig')
write(fixture(True));assert ui.refresh(s)==1
assert len(bpy.data.actions)==4 and len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2
assert s.gaf_clips[-1].status=='pending'
s.gaf_active_index=3;ui.activate(s,3)
assert bpy.data.objects[ui.RIG].animation_data.action.name=='Probe_Pending'
# Temporary process never saves any viewer/source file.
report={'passed':True,'duplicate_rejected':True,'changed_source_rejected':True,'missing_action_restored':True,'incompatible_rig_rolled_back':True,'compatible_action_imported_without_actor_duplication':True,'new_status_preserved_pending':True}
(OUT/'refresh_verification.json').write_text(json.dumps(report,indent=2))
print('REFRESH VERIFIED',json.dumps(report),flush=True)
