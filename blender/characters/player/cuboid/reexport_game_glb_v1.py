import bpy,json,ast
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
assert Path(bpy.data.filepath)==BASE/'player_cuboid_game_export_v1.blend'
manifest=json.loads((BASE/'export/player_cuboid_export_validation_input.json').read_text())
GLB=Path(manifest['glb']);baseline=manifest['baseline'];actions={a.name:a for a in bpy.data.actions};scene=bpy.context.scene
t=ast.parse((BASE/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='fcurves'],type_ignores=[]),'helper','exec'))
tree=ast.parse((BASE/'prepare_game_export_v1.py').read_text())
# Execute only the same transient time-coordinate sampling and export operator.
start=next(i for i,n in enumerate(tree.body) if isinstance(n,ast.For) and ast.unparse(n.target)=='a' and ast.unparse(n.iter)=='actions.values()')
end=next(i for i in range(start,len(tree.body)) if isinstance(tree.body[i],ast.Expr) and 'export_scene.gltf' in ast.unparse(tree.body[i]))
exec(compile(ast.Module(body=tree.body[start:end+1],type_ignores=[]),'export_only','exec'))
