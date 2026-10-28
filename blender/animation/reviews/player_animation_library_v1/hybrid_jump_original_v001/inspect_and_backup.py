"""Read-only source-study inspection and preservation snapshot before authoring."""
import bpy, json, hashlib, shutil, sys
from pathlib import Path
H=Path(__file__).resolve().parent; R=H.parents[4]
sys.path.insert(0,str(R/'blender/animation/showcase'))
import gaf_animation_library as ui
B=R/'.validation/animation_showcase/hybrid_jump_original_v001'
B.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
central=R/'blender/animation/showcase/Animation_Showcase.blend'
manifest=central.with_name('animation_manifest.json')
assert not (B/'baseline.json').exists(), 'Snapshot exists; do not replace original baseline'
for p in (central,manifest):shutil.copy2(p,B/p.name)
files={str(p):sha(p)for p in (central,manifest)}
godot={str(p.relative_to(R)):sha(p)for p in (R/'game_mobile_3d').rglob('*')if p.is_file() and '.godot'not in p.parts and p.suffix in ('.gd','.tscn','.tres','.godot','.gdshader','.json')}
data=json.loads(manifest.read_text(encoding='utf8'))
actions={a.name:ui.action_signature(a)for a in bpy.data.actions}
studies=[]
for name in ['Jump_Takeoff_Test','Jump_AirPose_Test','Jump_Landing_Impact_Test','Full_Jump_Expressive_v2_Test','Jump_ActionsStuff_Source_Test_v001','Landing_Stationary_ActionsStuff_Source_Test_v001']:
 a=bpy.data.actions[name];e=next(e for e in data['animations']if e['action']==name)
 paths={c.data_path for c in ui.curves(a)}
 studies.append({'action':name,'registered':e,'actual_range':list(a.frame_range),'curves':len(list(ui.curves(a))),'key_count':sum(len(c.keyframe_points)for c in ui.curves(a)),'animated_scale_paths':[p for p in paths if p.endswith('scale')],'sha':actions[name]})
(B/'baseline.json').write_text(json.dumps({'files':files,'actions':actions,'godot':godot,'registry_count':len(data['animations']),'review_count':len(data.get('review_sequences',[]))},indent=2),encoding='utf8')
(H/'existing_source_study_inspection.json').write_text(json.dumps({'studies':studies,'action_count':len(actions),'rig_bones':list(bpy.data.objects[ui.RIG].pose.bones.keys()),'rest_sha256':ui.rest_signature(bpy.data.objects[ui.RIG].data)},indent=2),encoding='utf8')
print('PRESERVED',len(actions),'actions;',len(godot),'Godot files; inspected both requested source studies',flush=True)
