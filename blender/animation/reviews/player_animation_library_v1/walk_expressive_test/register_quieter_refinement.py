"""Update only the backed-up Pending walk metadata after saved-source validation."""
import bpy,json,sys,hashlib,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test';SHOW=ROOT/'blender/animation/showcase';BACK=TMP/'before_quieter_sway'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();guard=json.loads((BACK/'hash_guard.json').read_text());manifest_path=SHOW/'animation_manifest.json'
assert sha(SHOW/'Animation_Showcase.blend')==guard['blender/animation/showcase/Animation_Showcase.blend'] and sha(manifest_path)==guard['blender/animation/showcase/animation_manifest.json'],'Concurrent library edit'
manifest=json.loads(manifest_path.read_text());before=json.loads((BACK/'files/blender/animation/showcase/animation_manifest.json').read_text());assert manifest==before
v=json.loads((OUT/'validation.json').read_text());a=bpy.data.actions['Walk_Expressive_Test'];r=bpy.data.objects['WEX_Test_Rig']
assert v['passed'] and v['source_sha256']==sha(Path(bpy.data.filepath)) and v['action_sha256']==ui.action_signature(a)
assert ui.rest_signature(r.data)==manifest['rig_sha256']
walk=manifest['animations'][-1];assert walk['action']=='Walk_Expressive_Test' and walk['status']=='pending'
walk['source_sha256']=v['source_sha256'];walk['action_sha256']=v['action_sha256']
walk['presentation_note']+=' Latest Pending refinement: lateral hip travel and dynamic torso side-roll halved; walking tracks narrowed from0.29m to0.27m. Fore/aft response, vertical receiving, stride timing,5deg toe-out and ground support retained.'
ui.validate_action(a,walk,r);assert manifest['animations'][:-1]==before['animations'][:-1]
(TMP/'working_tree_before_hip_registration.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
temp=manifest_path.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2));temp.replace(manifest_path)
(TMP/'quieter_registration_guard.json').write_text(json.dumps({'showcase_before':sha(SHOW/'Animation_Showcase.blend'),'manifest_after':sha(manifest_path),'source_sha256':v['source_sha256'],'walk_action_sha256':v['action_sha256']},indent=2))
print('REGISTERED PENDING WALK QUIETER SWAY / CLOSER TRACKS / ELEVEN ENTRIES UNCHANGED',flush=True)
