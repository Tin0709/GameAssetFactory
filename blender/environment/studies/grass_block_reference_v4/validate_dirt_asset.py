"""Bare dirt block contract; run in background Blender."""
import bpy
import hashlib
import json
import runpy
from pathlib import Path

STUDY=Path(__file__).resolve().parent
ROOT=STUDY.parents[3]
OUT=ROOT/'game_mobile_3d/assets/environment/grassland'
assert (OUT/'dirt_block_v4.glb').exists(), 'Missing bare dirt_block_v4.glb'
contract=runpy.run_path(str(STUDY/'validate_asset.py'))
manifest=json.loads((OUT/'export_manifest_v4.json').read_text())
dirt=bpy.data.objects['ENV_Dirt_Block_1m_V4']
dirt.data.calc_loop_triangles()
assert len(dirt.data.vertices)==8 and len(dirt.data.polygons)==6
assert len(dirt.data.loop_triangles)==12
assert tuple(round(v,7) for v in dirt.dimensions)==(1,1,1)
assert tuple(dirt.location)==(0,0,0) and tuple(dirt.scale)==(1,1,1)
assert not dirt.modifiers and not dirt.data.shape_keys
assert all(abs(v.co.z)<1e-7 or abs(v.co.z-1)<1e-7 for v in dirt.data.vertices)
image=bpy.data.images['ENV_Atlas_128_Reference_V4']
assert image.packed_file and tuple(image.size)==(128,128)
assert dirt.data.materials[0]==bpy.data.objects['ENV_Grass_Square_Leaves_V4'].data.materials[0]
for polygon in dirt.data.polygons:
    for li in polygon.loop_indices:
        uv=dirt.data.uv_layers['UV_Atlas'].data[li].uv
        assert 104/128 <= uv.y <= 127/128
for name,digest in manifest['bare_dirt_family']['preserved_v4_mesh_exports_sha256'].items():
    assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest
document,binary=contract['glb'](OUT/'dirt_block_v4.glb')
assert not document.get('animations') and not document.get('skins')
primitive=document['meshes'][0]['primitives'][0]
assert not primitive.get('targets')
positions=contract['accessor'](document,binary,primitive['attributes']['POSITION'])
indices=contract['accessor'](document,binary,primitive['indices'])
assert len(indices)//3==12
for axis in range(3):assert max(v[axis] for v in positions)-min(v[axis] for v in positions)==1
assert set(v[1] for v in positions)=={0,1}
uvs=contract['accessor'](document,binary,primitive['attributes']['TEXCOORD_0'])
assert all(1/128 <= uv[1] <= 24/128 for uv in uvs)
# All dirt swatches stay earthy rather than sampling the green atlas bands.
rgb=[list(image.pixels[(int(uv[1]*128)*128+int(uv[0]*128))*4:][:3]) for polygon in dirt.data.polygons for li in polygon.loop_indices for uv in [dirt.data.uv_layers[0].data[li].uv]]
assert all(c[0]>c[1]>c[2] for c in rgb)
report=dict(all_checks_passed=True,dimensions_m=list(dirt.dimensions),authored_vertices=8,triangles=12,
            no_grass_cap=True,existing_v4_mesh_exports_unchanged=True,
            existing_atlas_texels_unchanged_below_row104=True)
report['atlas_preservation_verified_in_builder']=manifest['bare_dirt_family']['atlas_unchanged_outside_new_tiles']
assert report['atlas_preservation_verified_in_builder']
(STUDY/'dirt_validation_report.json').write_text(json.dumps(report,indent=2))
print('V4_DIRT_VALIDATED '+json.dumps(report))
