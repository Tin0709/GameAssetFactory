"""Test pending registration in a disposable manifest, never the real library."""
import bpy,json,sys,shutil,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
import register_animation as reg
temp=OUT.parents[2]/'.validation/animation_showcase/registration_fixture'
temp.mkdir(exist_ok=True)
original=(OUT/'animation_manifest.json').read_bytes()
data=json.loads(original)
data['animations']=[e for e in data['animations'] if e['action']!='Run_Expressive_Test']
(temp/'animation_manifest.json').write_text(json.dumps(data))
shutil.copy2(OUT/'Animation_Showcase.blend',temp/'Animation_Showcase.blend')
reg.OUT=temp
entry=reg.register_entry('Run_Expressive_Test','RUN_Test_Rig','RUN_Test_Mesh',1,18,30)
assert entry['status']=='pending' and entry['action_frame_range']==[1.0,19.0]
before=(temp/'animation_manifest.json').read_bytes()
try:reg.register_entry('Run_Expressive_Test','RUN_Test_Rig','RUN_Test_Mesh',1,18,30)
except ValueError:pass
else:raise AssertionError('Duplicate registration accepted')
assert (temp/'animation_manifest.json').read_bytes()==before
assert (OUT/'animation_manifest.json').read_bytes()==original
report={'passed':True,'new_entry_pending':True,'closing_key_preserved':True,'duplicate_rejected_without_overwrite':True,'real_manifest_unchanged':True}
(OUT/'registration_verification.json').write_text(json.dumps(report,indent=2))
print('REGISTRATION VERIFIED',json.dumps(report),flush=True)
