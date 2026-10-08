"""Reproducible read-only native scatter export.

Run: blender --background --factory-startup --python-exit-code 1 --python
     blender/environment/export_scatter_e2.py
The source is opened in memory only, never saved. All export changes use copies.
Manifest dimensions are Godot/glTF Y-up metres (width, height, depth).
"""
import bpy
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'blender/environment/studies/environment_scatter_set_v1/environment_scatter_set_v1.blend'
ENV = ROOT / 'game_mobile_3d/assets/environment/grassland'
OUT = ENV / 'scatter_v1'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

source_hash = sha(SOURCE)
# Record existing finished environment exports without rebuilding them.
preserved = [{'file': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)}
             for p in sorted(ENV.iterdir()) if p.is_file() and p.suffix in ('.glb', '.png', '.json')]
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
originals = sorted((o for o in bpy.context.scene.objects if o.get('scatter_asset')), key=lambda o: o.name)
assert Counter(o['category'] for o in originals) == {'rock': 6, 'dirt': 4, 'flower': 8}
assert len(originals) == 18 and all(o.type == 'MESH' for o in originals)
assert all(not o.modifiers and not o.animation_data and not o.data.shape_keys for o in originals)
assert all(all(abs(v-1) < 1e-6 for v in o.scale) and all(abs(v) < 1e-6 for v in o.rotation_euler) for o in originals)
image = bpy.data.images['SCATTER_Palette_128_Opaque']
assert image.packed_file and list(image.size) == [128, 128]
assert all(abs(a-1) < 1e-6 for a in list(image.pixels)[3::4])
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'scatter_atlas_v1.png').write_bytes(bytes(image.packed_file.data))
scene = bpy.data.scenes.new('EXPORT_ONLY_SCATTER_E2')
bpy.context.window.scene = scene
assets = []
for original in originals:
    obj = original.copy()
    obj.data = original.data.copy()
    obj.animation_data_clear()
    obj.location = (0, 0, 0)
    scene.collection.objects.link(obj)
    # Preserve material nodes/packed image and UVs; no palette substitution.
    for material in obj.data.materials:
        assert material.use_nodes
        assert all(n.interpolation == 'Closest' for n in material.node_tree.nodes if n.type == 'TEX_IMAGE')
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    filename = original.name.lower()+'.glb'
    bpy.ops.export_scene.gltf(filepath=str(OUT / filename), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=False,
        export_skins=False, export_morph=False, export_yup=True,
        export_texcoords=True, export_normals=True, export_materials='EXPORT',
        export_image_format='AUTO', export_vertex_color='NONE')
    obj.data.calc_loop_triangles()
    dimensions = original.dimensions
    assets.append({'name': original.name, 'category': original['category'],
        'variant': original['variant'], 'file': filename,
        'res_path': 'res://assets/environment/grassland/scatter_v1/'+filename,
        'dimensions_m': [dimensions.x, dimensions.z, dimensions.y],
        'source_dimensions_blender_xyz_m': list(dimensions),
        'triangles': len(obj.data.loop_triangles), 'sha256': sha(OUT / filename)})
    bpy.data.objects.remove(obj, do_unlink=True)
assert sha(SOURCE) == source_hash
assert all(sha(ROOT / p['file']) == p['sha256'] for p in preserved)
manifest = {'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
    'source_unchanged': True, 'coordinate_system': 'glTF/Godot Y-up metres; bottom-center origin',
    'atlas': 'scatter_atlas_v1.png', 'atlas_sha256': sha(OUT / 'scatter_atlas_v1.png'),
    'assets': assets, 'preserved_existing_assets': preserved}
(OUT / 'export_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('SCATTER_EXPORT_PASS '+json.dumps({'assets': len(assets), 'source_unchanged': True, 'output': str(OUT)}))
