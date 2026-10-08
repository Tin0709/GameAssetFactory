"""Lossless preflight only. Missing asset states stop the Godot import."""
from collections import Counter
from pathlib import Path
import hashlib
import importlib.metadata
import json
import math
import struct
import nbtlib
from litemapy import Schematic, Region, BlockState

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / 'minecraft_maps/source/Testing.litematic'
AIR = {'minecraft:air', 'minecraft:cave_air', 'minecraft:void_air'}


def write(name, data):
    (OUT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')


def plain(value):
    if hasattr(value, 'unpack'):
        return plain(value.unpack())
    if isinstance(value, dict):
        return {str(k): plain(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [plain(v) for v in value]
    if hasattr(value, 'tolist'):
        return value.tolist()
    return value


def state(b):
    props = dict(sorted(b.properties()))
    key = b.id + ('[' + ','.join(f'{k}={v}' for k, v in props.items()) + ']' if props else '')
    return key, {'id': b.id, 'properties': props}


def raw_region(n):
    """Independent continuous packed-long decoder, not Litemapy's BitArray."""
    sizes = [int(n['Size'][k]) for k in 'xyz']
    origin = [int(n['Position'][k]) for k in 'xyz']
    palette = [state(BlockState.from_nbt(p))[0] for p in n['BlockStatePalette']]
    bits = max(2, (len(palette) - 1).bit_length())
    words = [int(w) & ((1 << 64) - 1) for w in n['BlockStates']]
    count = math.prod(map(abs, sizes))
    assert len(words) == (count * bits + 63) // 64
    result = {}
    for i in range(count):
        word, shift = divmod(i * bits, 64)
        value = words[word] >> shift
        if shift + bits > 64:
            value |= words[word + 1] << (64 - shift)
        index = value & ((1 << bits) - 1)
        assert index < len(palette)
        x = i % abs(sizes[0])
        z = (i // abs(sizes[0])) % abs(sizes[2])
        y = i // abs(sizes[0] * sizes[2])
        local = [q + min(0, s + 1) for q, s in zip((x, y, z), sizes)]
        pos = tuple(o + q for o, q in zip(origin, local))
        result[pos] = palette[index]
    return result


def library_region(r):
    return {(r.x+x, r.y+y, r.z+z): state(r[x,y,z])[0] for x,y,z in r.block_positions()}


def merge(regions):
    cells, owners, conflicts, duplicates = {}, {}, [], []
    for name, positions in regions.items():
        for pos, key in positions.items():
            if pos in cells:
                record = {'coordinate': list(pos), 'regions': [owners[pos], name], 'states': [cells[pos], key]}
                (duplicates if cells[pos] == key else conflicts).append(record)
                continue  # Conflict retained in report; never treated as a valid import.
            cells[pos], owners[pos] = key, name
    return cells, conflicts, duplicates


def parser_tests():
    r = Region(-7, -3, -11, -5, -3, -7)
    expected = {}
    for i, (x,y,z) in enumerate(r.block_positions()):
        b = BlockState('minecraft:air') if i % 33 == 0 else BlockState(f'minecraft:fixture_{i % 33}')
        r[x,y,z] = b
        expected[(r.x+x,r.y+y,r.z+z)] = state(b)[0]
    assert raw_region(r.to_nbt()) == library_region(r) == expected
    assert min(p[0] for p in expected) == -11 and min(p[1] for p in expected) == -5 and max(p[2] for p in expected) == -11
    cells, conflicts, dup = merge({'a': {(0,0,0): 'minecraft:air', (1,0,0): 'minecraft:stone'},
                                 'b': {(0,0,0): 'minecraft:dirt', (1,0,0): 'minecraft:stone', (5,-2,8): 'minecraft:stone'}})
    assert len(conflicts) == 1 and len(dup) == 1 and (5,-2,8) in cells
    return {'negative_xyz_offsets_and_sizes': 'PASS', 'long_word_boundary_6bit_palette': 'PASS',
            'multi_region_air_solid_conflict_and_same_state_duplicate': 'PASS'}


def asset_contract(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data)
    assert (magic, version, length) == (0x46546c67, 2, len(data))
    length, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4e4f534a
    doc = json.loads(data[20:20+length])
    assert len(doc['meshes']) == len(doc['nodes']) == 1
    node = doc['nodes'][0]
    assert not any(k in node for k in ['translation','rotation','scale','matrix'])
    primitive = doc['meshes'][0]['primitives'][0]
    assert len(doc['meshes'][0]['primitives']) == 1 and primitive.get('mode', 4) == 4
    pos = doc['accessors'][primitive['attributes']['POSITION']]
    dims = [hi-lo for lo,hi in zip(pos['min'], pos['max'])]
    assert abs(pos['min'][1]) < 1e-6
    assert all(abs(pos['min'][i] + pos['max'][i]) < 1e-6 for i in [0,2])
    tris = doc['accessors'][primitive['indices']]['count'] // 3
    material = doc['materials'][primitive['material']]
    assert 'TEXCOORD_0' in primitive['attributes'] and 'baseColorTexture' in material['pbrMetallicRoughness']
    assert doc['images'][0].get('mimeType') == 'image/png' and 'bufferView' in doc['images'][0]
    assert all(s.get('magFilter') == 9728 for s in doc['samplers'])
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(data).hexdigest(),
            'dimensions_gltf_xyz_m': dims, 'bounds_min': pos['min'], 'bounds_max': pos['max'],
            'pivot': 'bottom center', 'orientation': 'glTF +Y up, identity node', 'triangles': tris,
            'alpha_mode': material.get('alphaMode','OPAQUE'), 'double_sided': material.get('doubleSided',False),
            'material': 'original embedded 128px meadow atlas; nearest filtering'}


def main():
    assert SOURCE.exists(), SOURCE
    tests = parser_tests()
    before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    raw = nbtlib.load(str(SOURCE))
    schem = Schematic.load(str(SOURCE))
    palette, per_region, regions = {}, {}, []
    for name, r in schem.regions.items():
        cells = library_region(r)
        assert cells == raw_region(raw['Regions'][name]), f'Independent decode differs: {name}'
        for b in r.palette:
            key, detail = state(b)
            palette[key] = detail
        per_region[name] = cells
        regions.append({'name': name, 'origin': [r.x,r.y,r.z], 'signed_size': [r.width,r.height,r.length],
                        'local_min': [min(0,r.width+1),min(0,r.height+1),min(0,r.length+1)],
                        'volume': len(cells), 'counts_by_state': dict(sorted(Counter(cells.values()).items())),
                        'cells_including_air': [[*p,key] for p,key in sorted(cells.items())],
                        'entities': plain(raw['Regions'][name].get('Entities',[])),
                        'tile_entities': plain(raw['Regions'][name].get('TileEntities',[]))})
    cells, conflicts, duplicates = merge(per_region)
    occupied = {p:k for p,k in cells.items() if palette[k]['id'] not in AIR}
    counts = dict(sorted(Counter(occupied.values()).items()))
    bounds_min = [min(p[i] for p in cells) for i in range(3)]
    bounds_max = [max(p[i] for p in cells) for i in range(3)]
    dimensions = [b-a+1 for a,b in zip(bounds_min,bounds_max)]
    assert dimensions == [schem.width,schem.height,schem.length]
    assert sum(len(c) for c in per_region.values()) == int(raw['Metadata']['TotalVolume'])
    assert sum(sum(palette[k]['id'] not in AIR for k in c.values()) for c in per_region.values()) == int(raw['Metadata']['TotalBlocks'])
    by_id = Counter(palette[k]['id'] for k in occupied.values())
    tall_bad = []
    for p,k in occupied.items():
        if palette[k]['id'] != 'minecraft:tall_grass':
            continue
        half = palette[k]['properties']['half']
        q = (p[0],p[1] + (1 if half == 'lower' else -1),p[2])
        expected_half = 'upper' if half == 'lower' else 'lower'
        if occupied.get(q) != f'minecraft:tall_grass[half={expected_half}]':
            tall_bad.append({'coordinate':list(p),'state':k,'expected_partner':list(q)})
    exports = ROOT/'blender/environment/studies/dungeons_ground_style_v2/exports'
    contracts = {n:asset_contract(exports/f'{n}_di_study_{v}.glb') for n,v in
                 [('grass_block','v1'),('dirt_block','v2'),('stone_block','v2'),('grass','v1'),('tall_grass','v1')]}
    for n in ['grass_block','dirt_block','stone_block']:
        assert all(abs(v-1)<1e-6 for v in contracts[n]['dimensions_gltf_xyz_m'])
        assert contracts[n]['triangles'] == 12 and contracts[n]['alpha_mode'] == 'OPAQUE'
    for n in ['grass','tall_grass']:
        assert contracts[n]['triangles'] == 4 and contracts[n]['alpha_mode'] == 'MASK' and contracts[n]['double_sided']
    mapping = {'minecraft:dirt':'dirt_block','minecraft:grass_block[snowy=false]':'grass_block',
               'minecraft:stone':'stone_block','minecraft:short_grass':'grass'}
    registry = []
    for key, count in counts.items():
        asset = mapping.get(key)
        registry.append({'state':key, **palette[key], 'count':count, 'supported':asset is not None,
                         'asset':contracts[asset] if asset else None,
                         'reason': 'existing matching reusable asset' if asset else
                         'No authored lower/upper tall-grass shape variant. Existing whole tuft is 0.95m high, not a two-cell plant; do not duplicate it in both cells or silently stretch it.'})
    missing = [r for r in registry if not r['supported']]
    summary = {'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256':before,
               'parser_versions':{m:importlib.metadata.version(m) for m in ['litemapy','nbtlib','numpy']},
               'metadata':plain(raw['Metadata']), 'format_version':int(raw['Version']),
               'minecraft_data_version':int(raw['MinecraftDataVersion']), 'dimensions':dimensions,
               'bounds_inclusive':{'min':bounds_min,'max':bounds_max}, 'region_count':len(regions),
               'cells_including_air':len(cells), 'air_cells':len(cells)-len(occupied),
               'occupied_blocks':len(occupied), 'occupied_unique_ids':len(by_id),
               'occupied_state_variants':len(counts), 'counts_by_id':dict(sorted(by_id.items())),
               'counts_by_state':counts, 'conflicts':conflicts, 'identical_overlaps':duplicates,
               'unpaired_tall_grass':tall_bad,
               'coordinate_plan':{'status':'documented only; Godot orientation test NOT run',
                   'one_global_origin':bounds_min,'cell_transform':'g=(x-ox,y-oy,z-oz); no axis swap or mirror',
                   'bottom_center_asset_translation':'(gx+0.5,gy,gz+0.5)',
                   'scale':'1 block = 1 Godot unit', 'axes':'+X east, +Y up, +Z south; north -Z'},
               'source_decoding_validation':{'all_region_cells_independently_equal':True,'metadata_counts_match':True,
                   'synthetic_cases':tests},
               'godot_reconstruction_validation':{'status':'NOT RUN — asset coverage gate blocked',
                   'imported_blocks':0,'scene_created':False,'playable_test':False},
               'status':'STOP_MISSING_ASSET_STATES' if missing else 'PREFLIGHT_READY'}
    write('map_data.json', {'schema':'m2-lossless-preflight-v1','summary':summary,'state_palette':palette,
                            'regions':regions,'occupied_global_cells':[[*p,k] for p,k in sorted(occupied.items())]})
    write('source_audit.json',summary)
    write('asset_registry.json',{'entries':registry,'air':'empty cell; no geometry','candidate_whole_tall_grass':contracts['tall_grass']})
    write('missing_assets.json',{'status':summary['status'],'missing_state_variants':missing,
                               'affected_occupied_cells':sum(r['count'] for r in missing),
                               'unpaired_tall_grass':tall_bad,'action':'Stop before Godot import; do not substitute placeholders as final.'})
    write('mismatch_report.json',{'source_vs_independent_decode_mismatches':0,
        'conflicting_cells':conflicts,'identical_overlaps':duplicates,'tall_grass_pair_errors':tall_bad,
        'godot_placement_mismatches':None,'godot_state_mismatches':None,
        'note':'Godot counts and placement not validated: no map imported because of missing assets.'})
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == before
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
