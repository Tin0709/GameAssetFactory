"""Export-only E1 copies. Run in factory-startup background Blender, never save source."""
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'blender/environment/studies/grass_block_wind_v3/grass_block_wind_v3.blend'
OUT = ROOT / 'game_mobile_3d/assets/environment/grassland'
OUT.mkdir(parents=True, exist_ok=True)
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.data.scenes['ENV_Grass_Block_Wind_Review']
bpy.context.window.scene = scene
scene.frame_set(1)
block = bpy.data.objects['ENV_GrassDirt_Block_1m']
grass = bpy.data.objects['ENV_Grass_Full_Surface_2D']
assert tuple(round(v, 5) for v in block.dimensions) == (1, 1, 1)
assert len(grass.data.vertices) == 392
assert grass.data.uv_layers.get('UV_Blade_Root')
assert grass.data.color_attributes.get('GRASS_BEND_DATA')
assert not block.modifiers and not grass.modifiers

report = {'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': source_hash,
          'objects': [block.name, grass.name, 'ENV_Wind_Global'],
          'material': 'ENV_Pixel_Atlas_Opaque', 'texture': 'ENV_Atlas_64_Nearest',
          'adjustments': [], 'grass_vertices': len(grass.data.vertices),
          'grass_triangles': 294, 'height_rings': [0, .22, .65, 1],
          'wind_seconds': 4, 'wind_tip_x_m': .018, 'wind_tip_y_m': .007}
image = bpy.data.images['ENV_Atlas_64_Nearest']
(OUT / 'environment_atlas_64.png').write_bytes(bytes(image.packed_file.data))

# Copy source data; use the authored rest basis, with shader motion as sole writer.
export_collection = bpy.data.collections.new('EXPORT_ONLY_Grassland_E1')
scene.collection.children.link(export_collection)
copies = []
for original in (block, grass):
    obj = original.copy()
    obj.data = original.data.copy()
    obj.animation_data_clear()
    export_collection.objects.link(obj)
    obj.name = original.name + '_E1_Export'
    if original == grass:
        basis = [v.co.copy() for v in original.data.shape_keys.key_blocks['Basis'].data]
        obj.shape_key_clear()
        for v, co in zip(obj.data.vertices, basis): v.co = co
        obj.location = (0, 0, 0)
        obj.data.color_attributes.active_color = obj.data.color_attributes['GRASS_BEND_DATA']
        obj.data.color_attributes.render_color_index = obj.data.color_attributes.find('GRASS_BEND_DATA')
    else:
        # The flat top/bottom n-gons contain 32 collinear rim vertices each.
        # Remove only their redundant collinear points, retaining source corner UVs.
        mesh = obj.data
        coords = [v.co.copy() for v in mesh.vertices]
        faces, uv_faces = [], []
        for polygon in mesh.polygons:
            loops = list(polygon.loop_indices)
            if all(abs(coords[mesh.loops[i].vertex_index].z - coords[mesh.loops[loops[0]].vertex_index].z) < 1e-7 for i in loops) and (polygon.center.z < 1e-6 or polygon.center.z > .999999):
                kept = []
                for k, li in enumerate(loops):
                    prev = coords[mesh.loops[loops[k-1]].vertex_index]
                    here = coords[mesh.loops[li].vertex_index]
                    nxt = coords[mesh.loops[loops[(k+1) % len(loops)]].vertex_index]
                    if (here-prev).cross(nxt-here).length > 1e-8: kept.append(li)
                loops = kept
            faces.append([mesh.loops[i].vertex_index for i in loops])
            uv_faces.append([tuple(mesh.uv_layers[0].data[i].uv) for i in loops])
        optimized = bpy.data.meshes.new('ENV_Block_E1_Export_Only')
        optimized.from_pydata(coords, [], faces)
        optimized.materials.append(mesh.materials[0])
        uv = optimized.uv_layers.new(name='UV_Atlas')
        for polygon, values in zip(optimized.polygons, uv_faces):
            for li, value in zip(polygon.loop_indices, values): uv.data[li].uv = value
        optimized.update()
        obj.data = optimized
        report['adjustments'].append('Export copy only: simplify collinear top/bottom n-gon boundary points. Same planar surface, corners, UVs and stepped side geometry.')
    copies.append(obj)

export_scene = bpy.data.scenes.new('EXPORT_ONLY_E1')
export_scene.collection.children.link(export_collection)
bpy.context.window.scene = export_scene
properties = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
options = dict(export_format='GLB', use_selection=True, export_animations=False,
               export_skins=False, export_morph=False, export_yup=True,
               export_texcoords=True, export_normals=True, export_materials='EXPORT',
               use_active_scene=True, export_vertex_color='ACTIVE')
for key, value in [('export_all_vertex_colors', True), ('export_active_vertex_color_when_no_material', True)]:
    if key in properties: options[key] = value
for obj, filename in zip(copies, ['grass_dirt_block_v3.glb', 'grass_patch_v3.glb']):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / filename), **options)
    obj.data.calc_loop_triangles()
    report[filename] = {'triangles': len(obj.data.loop_triangles),
                       'vertices': len(obj.data.vertices), 'location': list(obj.location),
                       'uv_layers': [layer.name for layer in obj.data.uv_layers],
                       'color_attributes': [a.name for a in obj.data.color_attributes]}
assert source_hash == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
report['source_unchanged'] = True
(OUT / 'export_manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('GRASSLAND_EXPORT ' + json.dumps(report))
