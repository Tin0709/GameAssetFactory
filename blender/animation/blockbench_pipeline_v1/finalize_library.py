"""Finalize the five test registrations after validation; retain 28 original entries."""
import bpy,json,sys,hashlib,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];SHOWCASE=HERE.parent/'showcase';BEFORE=ROOT/'.validation/blockbench_pipeline_v1/before'
sys.path.insert(0,str(SHOWCASE));import gaf_animation_library as ui
viewer=SHOWCASE/'Animation_Showcase.blend';path=SHOWCASE/'animation_manifest.json';source=HERE/'blockbench_import_source_v001.blend'
hashes=json.loads((BEFORE/'file_hashes.json').read_text());assert hashlib.sha256(viewer.read_bytes()).hexdigest()==hashes[str(viewer.relative_to(ROOT))],'Concurrent viewer edit'
original=json.loads((BEFORE/'blender/animation/showcase/animation_manifest.json').read_text());manifest=json.loads(path.read_text());assert manifest['animations'][:28]==original['animations'];assert len(manifest['animations'])==33
signatures=json.loads((HERE/'validation/before_action_signatures.json').read_text())
for n,d in signatures.items():assert ui.action_signature(bpy.data.actions[n])==d,n
assert ui.rest_signature(bpy.data.objects['Showcase_Player_Rig'].data)==original['rig_sha256']
backup=ROOT/'.validation/blockbench_pipeline_v1/before_final_registration';backup.mkdir(parents=True,exist_ok=True);shutil.copy2(path,backup/path.name)
source_hash=hashlib.sha256(source.read_bytes()).hexdigest();contract=json.loads((HERE/'bridge_contract.json').read_text())
for e in manifest['animations'][28:]:
 assert e['status']=='pending' and e['action'].startswith('BB_')
 a=bpy.data.actions[e['action']];e['source_sha256']=source_hash;e['action_sha256']=ui.action_signature(a);e['blockbench_contract_sha256']=contract['sha256'];e['blockbench_samples_sha256']=hashlib.sha256((ROOT/e['blockbench_samples']).read_bytes()).hexdigest();ui.validate_action(a,e,bpy.data.objects['Showcase_Player_Rig'])
path.write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.open_mainfile(filepath=str(viewer))
if not hasattr(bpy.types.Scene,'gaf_clips'):ui.register()
count=ui.refresh(bpy.context.scene);assert count==5,count
rig=bpy.data.objects['Showcase_Player_Rig'];assert len([o for o in bpy.data.objects if o.type=='ARMATURE'])==1
for n,d in signatures.items():assert ui.action_signature(bpy.data.actions[n])==d,n
assert hashlib.sha256(viewer.read_bytes()).hexdigest()==hashes[str(viewer.relative_to(ROOT))],'Concurrent viewer edit'
bpy.context.scene.gaf_active_index=32;ui.activate(bpy.context.scene,32)
bpy.ops.wm.save_as_mainfile(filepath=str(viewer))
print('SAVED 33 Actions: 28 preserved, 5 new Pending, one original rig')
