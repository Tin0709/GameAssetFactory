"""Package saved lossless M2 cells; does not parse or mutate the schematic."""
import collections, hashlib, json, pathlib, shutil
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'game_mobile_3d/assets/environment/litematic_m2_v1'
LOWER = 'minecraft:tall_grass[half=lower]'
UPPER = 'minecraft:tall_grass[half=upper]'

def collect_cells(data):
    cells = []
    for region in data['regions']:
        for x,y,z,state in region['cells_including_air']:
            cells.append([x,y,z,state]) # Existing reader rows are schematic-global already.
    if len({tuple(c[:3]) for c in cells}) != len(cells):
        raise ValueError('duplicate/conflicting global cells across regions')
    return cells

def prepare():
    data = json.loads((ROOT / 'minecraft_maps/m2_v1/map_data.json').read_text())
    cells = collect_cells(data)
    lookup = {tuple(c[:3]):c[3] for c in cells}
    assert len(lookup) == len(cells) == 15000, 'duplicate/missing volume cells'
    assert set(lookup) == {(x,y,z) for x in range(50) for y in range(6) for z in range(50)}
    counts = collections.Counter(c[3] for c in cells)
    assert sorted(c for c in cells if c[3] != 'minecraft:air') == sorted(data['occupied_global_cells'])
    for (x,y,z), state in lookup.items():
        if state == LOWER: assert lookup.get((x,y+1,z)) == UPPER, f'unpaired lower {x,y,z}'
        if state == UPPER: assert lookup.get((x,y-1,z)) == LOWER, f'unpaired upper {x,y,z}'
    assert counts[LOWER] == counts[UPPER] == 50
    files = {'minecraft:dirt':'dirt_block_di_study_v2.glb', 'minecraft:grass_block[snowy=false]':'grass_block_di_study_v1.glb', 'minecraft:stone':'stone_block_di_study_v2.glb', 'minecraft:short_grass':'grass_di_study_v1.glb', LOWER:'tall_grass_m2_v1.glb', UPPER:'tall_grass_m2_v1.glb'}
    assert set(counts) == set(files) | {'minecraft:air'}, 'unsupported state'
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for state,name in files.items():
        folder = 'dungeons_tall_grass_m2_v1' if name == 'tall_grass_m2_v1.glb' else 'dungeons_ground_style_v2/exports'
        src = ROOT / 'blender/environment/studies' / folder / name
        assert src.exists(), src
        shutil.copyfile(src, OUT/name)
        entries.append({'state':state,'count':counts[state], 'supported':True,'asset':f'res://assets/environment/litematic_m2_v1/{name}', 'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'render': 'paired_occupancy' if state == UPPER else ('plant' if 'grass[' in state or state=='minecraft:short_grass' else 'solid')})
    shutil.copyfile(ROOT/'blender/environment/studies/dungeons_tall_grass_m2_v1/meadow_m2_atlas.png', OUT/'meadow_m2_atlas.png')
    runtime = {'schema':1,'dimensions':[50,6,50], 'source_min':[0,0,0],'source_sha256':data['summary']['source_sha256'], 'regions':[{k:r[k] for k in ['name','origin','signed_size','local_min']} for r in data['regions']], 'cells':cells,'counts':dict(counts),'registry':entries,'air':'minecraft:air','tall_pairs':50}
    (OUT/'runtime_map.json').write_text(json.dumps(runtime, separators=(',',':')))
    (OUT/'asset_registry.json').write_text(json.dumps({'entries':entries,'unsupported':[],'historical_source_audit':'minecraft_maps/m2_v1/source_audit.json (preflight status only)'},indent=2))
    (OUT/'missing_assets.json').write_text(json.dumps({'missing':[],'unsupported':[],'pairs':50,'status':'complete'},indent=2))
    print(json.dumps({'volume':len(cells),'counts':dict(counts),'pairs':50,'unsupported':0}))

if __name__ == '__main__': prepare()
