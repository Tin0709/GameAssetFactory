"""Append one Pending entry and preserve all current central-library Actions."""
import bpy
import hashlib
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
LIB = ROOT / 'blender/animation/showcase'
TMP = ROOT / '.validation/run_snappy_leg_recovery_v001'
sys.path.insert(0, str(LIB))
import gaf_animation_library as ui
from register_animation import register_entry

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
name = 'Run_Snappy_LegRecovery_Test_v001'
validation = json.loads((OUT/'motion_validation.json').read_text())
assert validation['passed']
assert validation['source_sha256'] == sha(Path(bpy.data.filepath))
ledger = json.loads((TMP/'protected_files.json').read_text())
for path in ['blender/animation/showcase/Animation_Showcase.blend','blender/animation/showcase/animation_manifest.json']:
    assert sha(ROOT/path) == ledger[path], 'Concurrent library edit: '+path
old_manifest = json.loads((LIB/'animation_manifest.json').read_text())
entry = register_entry(name,'Showcase_Player_Rig','Showcase_Player_Mesh',1,17,30)
manifest = json.loads((LIB/'animation_manifest.json').read_text())
entry = manifest['animations'][-1]
entry.update(seamless_loop=True, closing_key=18, period_s=17/30, in_place=True,
             nominal_speed_m_s=2.5, contact_frames={'L':1,'R':9.5}, support_duty={'L':.39,'R':.40},
             baseline_action='Run_Snappy_Test_v001',
             approval_note='Pending human review: free-leg gather/release/open-stride experiment; approved upper body, body bounce, cadence and support preserved. No production promotion.',
             review_video=str((OUT/'candidate_three_views_1x.mp4').relative_to(ROOT)),
             gameplay_review='docs/animation/reviews/godot_snappy_run_leg_recovery_v001/README.md')
assert manifest['animations'][:-1] == old_manifest['animations']
(LIB/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
manifest_hash = sha(LIB/'animation_manifest.json')
bpy.ops.wm.open_mainfile(filepath=str(LIB/'Animation_Showcase.blend'),load_ui=False)
ui.register()
scene = bpy.context.scene
before = {a.name:ui.action_signature(a) for a in bpy.data.actions}
assert len(before) == 28 and all(ui.action_signature(bpy.data.actions[e['action']]) == e['action_sha256'] for e in old_manifest['animations'])
assert ui.refresh(scene) == 1
assert len(scene.gaf_clips) == len(bpy.data.actions) == 29
assert all(ui.action_signature(bpy.data.actions[n]) == h for n,h in before.items())
scene.gaf_active_index = 28
ui.activate(scene,28)
ui.view(scene,'THREE_QUARTER')
scene.gaf_loop=True
assert sha(LIB/'Animation_Showcase.blend') == ledger['blender/animation/showcase/Animation_Showcase.blend']
assert sha(LIB/'animation_manifest.json') == manifest_hash
bpy.ops.wm.save_as_mainfile(filepath=str(LIB/'Animation_Showcase.blend'),relative_remap=False,compress=True)
report=dict(previous_actions=before, previous_count=28, current_count=29, candidate_status='pending',
            previous_entries_exact=True, previous_action_signatures_exact=True,
            showcase_sha256=sha(LIB/'Animation_Showcase.blend'), manifest_sha256=manifest_hash)
(OUT/'registration.json').write_text(json.dumps(report,indent=2))
print('REGISTERED_ONE_PENDING_ACTION_ALL_28_PRESERVED',flush=True)
