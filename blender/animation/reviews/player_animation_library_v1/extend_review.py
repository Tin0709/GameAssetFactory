"""Apply the additive review update to the open review copy only."""
import bpy, json, ast, sys
from pathlib import Path
from mathutils import Matrix
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'player_animation_library_v1.blend').resolve()
sc=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1']
bpy.context.window.scene=sc
catalog=json.loads(sc['review_catalog']);actors=json.loads(sc['review_actors'])
tree=ast.parse((OUT/'create_review.py').read_text(encoding='utf-8'))
for node in tree.body:
    if isinstance(node,ast.FunctionDef) and node.name in ['assign','clone_actor','entry']:
        exec(compile(ast.Module(body=[node],type_ignores=[]),'review_helpers','exec'))
sys.path.insert(0,str(OUT))
from additional_reviews import add_armed_strafes,add_jump_slices
add_armed_strafes(sc,catalog,actors,clone_actor,entry,assign)
if not any(e['label']=='Jump up / lead A' for e in catalog):add_jump_slices(catalog)
else:
    for i,e in enumerate(catalog):e['id']=str(i)
sc['review_catalog']=json.dumps(catalog);sc['review_actors']=json.dumps(actors)
control=bpy.data.texts['START_HERE_review_controls.py'];control.clear()
control.write((OUT/'review_controls.py').read_text(encoding='utf-8'))
exec(compile(control.as_string(),control.name,'exec'),{'__name__':'player_review_controls'})
sc.player_review_group='Combat Strafe';sc.player_review_weapon='Rifle'
bpy.ops.player_review.select(clip_id=next(e['id'] for e in catalog if e['label']=='Strafe Right / Rifle'))
for w in bpy.context.window_manager.windows:w.scene=sc
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,check_existing=False)
m=json.loads((OUT/'review_manifest.json').read_text(encoding='utf-8'))
m.update(catalog=catalog,actors=actors,catalog_entries=len(catalog))
(OUT/'review_manifest.json').write_text(json.dumps(m,indent=2),encoding='utf-8')
print('Updated review:',len(catalog),'entries')
