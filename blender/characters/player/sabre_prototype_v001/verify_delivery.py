"""Read-only final integrity check; saves numeric/hash evidence, never assets."""
from pathlib import Path
import hashlib, json, os, re, subprocess

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[3]
RESEARCH = Path(os.environ.get('MD2_RESEARCH_ROOT', str(Path.home() / 'Desktop/MD2 Research')))
OUT = PROJECT / '.validation/md2_sabre_prototype_v001'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    checks = {}
    baseline = json.loads((OUT / 'preservation-baseline.json').read_text(encoding='utf-8'))
    changed = [name for name, row in baseline.items() if not (PROJECT / name).is_file() or digest(PROJECT / name) != row['sha256']]
    format_only = []
    config_name = 'game_mobile_3d/project.godot'
    if config_name in changed:
        config = (PROJECT / config_name).read_bytes()
        original_crlf = config.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
        if hashlib.sha256(original_crlf).hexdigest() == baseline[config_name]['sha256']:format_only.append(config_name)
    scene_name = 'game_mobile_3d/scenes/dev/ActionsStuffWalkRunTest.tscn'
    checks['preserved_baseline_except_lab_entry_and_f6_flag'] = set(changed)-set(format_only) == {scene_name, 'game_mobile_3d/scenes/dev/actions_stuff_research/walk_run_test.gd'}
    scene_bytes = (PROJECT / scene_name).read_bytes()
    original_scene = scene_bytes.replace(b'md2_sabre_prototype_enabled = true\r\n',b'',1).replace(b'md2_sabre_prototype_enabled = true\n',b'',1)
    checks['saved_scene_only_adds_f6_sabre_default'] = hashlib.sha256(original_scene).hexdigest() == baseline[scene_name]['sha256']
    checks['own_fallback_glb_matches_project_copy'] = digest(HERE / 'Sabre_Character_Authored.glb') == digest(PROJECT / 'game_mobile_3d/scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/Sabre_Character_Authored.glb')
    private = RESEARCH / 'blender/prototype_sabre'
    manifest = json.loads((private / 'MD2_Valorie_Sabre_Source.json').read_text(encoding='utf-8'))
    source_validation = json.loads((RESEARCH / 'reports/prototype_sabre/source_bundle_validation.json').read_text(encoding='utf-8'))
    checks['source_glb_matches_validated_hash'] = digest(private / manifest['glb']) == manifest['glb_sha256'] == source_validation['glb_sha256']
    checks['source_blender_matches_saved_hash'] = digest(private / manifest['blender']) == manifest['blender_sha256'] == source_validation['blender']['sha256']
    checks['all_original_inputs_unchanged'] = all(digest(Path(name)) == expected for name, expected in manifest['inputs_sha256'].items())
    checks['original32_joint_source_profile'] = manifest['joint_count'] == 32 and len(manifest['rig_bones']) == 32
    checks['22_semantic_states_13_originals_9_aliases'] = len(manifest['clips']) == 22 and len({x['source_file'] for x in manifest['clips'].values()}) == 13 and sum(x['source_alias_adapter'] for x in manifest['clips'].values()) == 9
    checks['all_original_animation_payloads_verified'] = all(x['all_channel_payloads_and_interpolation_exact'] for x in source_validation['exact_motion_aliases']) and sum(x['channels'] for x in source_validation['exact_motion_aliases']) == 2112
    checks['blender_sampled_source_matrix_error_below_1e_6'] = source_validation['blender']['maximum_sampled_joint_world_matrix_error'] < 1e-6
    checks['original_character_and_sabre_in_saved_blender'] = source_validation['blender']['character_vertices'] == 608 and source_validation['blender']['source_sabre_vertices'] == 970
    checks['source_blender_ui_and_launchers_exist'] = all((private / x).is_file() for x in ['source_preview_ui.py', 'Open MD2 Valorie Sabre.cmd']) and (HERE / 'Open Sabre Showcase.cmd').is_file() and (PROJECT / 'Open Sabre Prototype.cmd').is_file()
    reopened = json.loads((RESEARCH / 'reports/prototype_sabre/source_bundle_reopened.json').read_text(encoding='utf-8'))
    checks['saved_source_blender_reopened_16_checks_pass'] = reopened['all_passed'] and len(reopened['checks']) == 16 and all(reopened['checks'].values())
    media = json.loads((RESEARCH / 'reports/prototype_sabre/private_media_manifest.json').read_text(encoding='utf-8'))
    media_rows = [row for group in media['groups'].values() for row in group]
    checks['15_original_audio_hashes_unchanged_crc_valid'] = len(media_rows) == 15 and all(digest(RESEARCH / row['source']) == row['sha256'] and row['crc_failed_pages'] == 0 for row in media_rows)
    game_validation = PROJECT / 'game_mobile_3d/.validation/md2_sabre_prototype_v001'
    audio_validation = json.loads((game_validation / 'reference-audio.json').read_text(encoding='utf-8'))
    checks['source_audio_decoded_and_behaviour_verified'] = not audio_validation['failures'] and audio_validation['checks'] >= 18 and audio_validation['available_sources'] == 15
    asset_dir = PROJECT / 'game_mobile_3d/scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets'
    own_atlas = 'Sabre_Character_Authored_Sabre_AuthoredAtlas_128.png'
    checks['new_project_assets_only_authored_fallback'] = {p.name for p in asset_dir.iterdir() if p.suffix.lower() in {'.glb','.png','.ogg','.wav','.blend'}} == {'Sabre_Character_Authored.glb', own_atlas}
    checks['project_atlas_is_own_authored_atlas'] = digest(asset_dir / own_atlas) == digest(HERE / 'Sabre_AuthoredAtlas_128.png')
    suites = {}
    for name in ['test_state','test_runtime','test_private_loading','test_mode_switch','test_review','test_facing','test_source_profile','test_reference_audio','test_motion_calibration','test_locomotion_direction']:
        log = (OUT / (name + '-root-final.log')).read_text(encoding='utf-8-sig')
        rows = re.findall(r'^SABRE_\w+ (\{.*\})$', log, re.MULTILINE)
        suites[name] = json.loads(rows[-1]) if rows else {'failures': ['missing test result'], 'checks': 0}
    checks['ten_runtime_suites_at_least_242_checks_pass'] = len(suites) == 10 and all(not row['failures'] for row in suites.values()) and sum(row['checks'] for row in suites.values()) >= 242
    git_assets = subprocess.run(['git','-C',str(RESEARCH),'ls-files','--','*.glb','*.gltf','*.blend','*.blend[0-9]*','*.png','*.jpg','*.ogg','*.wav','*.mp4','*.avi','*.npz'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout
    checks['research_git_no_longer_tracks_art_media_assets'] = not git_assets.strip()
    report = {'checks': checks, 'failures': [k for k,v in checks.items() if not v], 'baseline_files': len(baseline), 'changed_baseline_files': changed, 'editor_line_ending_only_changes': format_only,
              'source_glb_sha256': manifest['glb_sha256'], 'source_blender_sha256': manifest['blender_sha256'],
              'research_root': str(RESEARCH), 'runtime_check_count': sum(row['checks'] for row in suites.values()), 'phone_optimized': False}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'delivery-validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 1 if report['failures'] else 0

if __name__ == '__main__':
    raise SystemExit(main())
