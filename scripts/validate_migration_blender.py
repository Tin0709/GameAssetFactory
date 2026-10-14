"""Read-only saved-Showcase and external dependency audit for migration."""
import hashlib
import importlib
import json
from pathlib import Path
import subprocess
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.validation/repository_migration_20261014'
OUT.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = {'showcases': {}, 'external_dependencies': [], 'missing_dependencies': []}


def external_dependencies(path):
    for image in bpy.data.images:
        if image.source not in ['FILE', 'TILED', 'MOVIE', 'SEQUENCE'] or image.packed_file or image.packed_files:
            continue
        if not image.filepath: continue
        resolved = Path(bpy.path.abspath(image.filepath, library=image.library))
        row = {'blend': path.relative_to(ROOT).as_posix(), 'kind': 'image',
               'name': image.name, 'stored': image.filepath, 'exists': resolved.is_file()}
        report['external_dependencies'].append(row)
        if not row['exists']: report['missing_dependencies'].append(row)
    for library in bpy.data.libraries:
        resolved = Path(bpy.path.abspath(library.filepath, library=library.parent))
        row = {'blend': path.relative_to(ROOT).as_posix(), 'kind': 'library',
               'stored': library.filepath, 'exists': resolved.is_file()}
        report['external_dependencies'].append(row)
        if not row['exists']: report['missing_dependencies'].append(row)


folder = ROOT / 'blender/animation/showcase'
sys.path.insert(0, str(folder))
ui = importlib.import_module('gaf_animation_library'); ui.register()
path = folder / 'Animation_Showcase.blend'; before = sha(path)
bpy.ops.wm.open_mainfile(filepath=str(path))
scene = bpy.context.scene; rig = bpy.data.objects[ui.RIG]
manifest = ui.load_manifest()
assert ui.rest_signature(rig.data) == manifest['rig_sha256']
assert ui.refresh(scene, import_missing=False) == 0
signatures = {a.name: ui.action_signature(a) for a in bpy.data.actions}
for index, entry in enumerate(manifest['animations']):
    assert sha(ROOT / entry['source']) == entry['source_sha256'], entry['source']
    ui.validate_action(bpy.data.actions[entry['action']], entry, rig)
    scene.gaf_active_index = index; ui.activate(scene, index)
    assert rig.animation_data.action.name == entry['action']
    assert [scene.frame_start, scene.frame_end] == [entry['start'], entry['end']]
    assert rig.animation_data.action_slot.identifier == entry['slot_identifier']
    for frame in [entry['start'], (entry['start']+entry['end'])/2, entry['end']]:
        scene.frame_set(int(frame), subframe=frame % 1); bpy.context.view_layer.update()
    assert not scene.gaf_error, scene.gaf_error
assert signatures == {a.name: ui.action_signature(a) for a in bpy.data.actions}
assert sha(path) == before
report['showcases']['animation'] = {'passed': True, 'entries': len(manifest['animations']),
    'actions': len(signatures), 'action_signatures_exact': True, 'source_hashes_exact': True,
    'selection_slots_playback_ranges_evaluate': True, 'source_file_sha256': before}
external_dependencies(path)

folder = ROOT / 'blender/weapons/showcase'; sys.path.insert(0, str(folder))
weapons = importlib.import_module('gaf_weapon_library'); weapons.register()
path = folder / 'Weapon_Showcase.blend'; before = sha(path)
bpy.ops.wm.open_mainfile(filepath=str(path)); scene = bpy.context.scene
manifest = json.loads((folder / 'weapon_manifest.json').read_text())
assert len(scene.gaf_weapons) == len(manifest['weapons'])
for index, entry in enumerate(manifest['weapons']):
    assert sha(ROOT / entry['source']) == entry['source_sha256'], entry['source']
    scene.gaf_weapon_index = index
    for mode in ['STANDALONE', 'READY', 'HOLSTER']:
        scene.gaf_fit_mode = mode; weapons.activate(scene)
        for direction in ['FRONT', 'LEFT', 'THREE_QUARTER']:
            weapons.view(scene, direction); bpy.context.view_layer.update()
assert not bpy.data.actions
assert sha(path) == before
report['showcases']['weapon'] = {'passed': True, 'entries': len(manifest['weapons']),
    'all_fit_modes_selectable': True, 'source_hashes_exact': True, 'source_file_sha256': before}
external_dependencies(path)

if '--all-blends' in sys.argv:
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    paths = [ROOT / p for p in tracked if p.endswith('.blend')]
    for index, path in enumerate(paths):
        bpy.ops.wm.open_mainfile(filepath=str(path)); external_dependencies(path)
        if index % 20 == 0: print('BLEND_DEPENDENCY_PROGRESS', index, len(paths), flush=True)
    report['all_blends_scanned'] = len(paths)
report['passed'] = not report['missing_dependencies']
(OUT / 'blender_validation.json').write_text(json.dumps(report, indent=2))
print('BLENDER_MIGRATION_AUDIT', json.dumps({'showcases': report['showcases'],
      'missing_dependencies': len(report['missing_dependencies']),
      'all_blends_scanned': report.get('all_blends_scanned')}), flush=True)
