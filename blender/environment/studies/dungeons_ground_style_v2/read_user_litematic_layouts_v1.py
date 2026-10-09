"""Read user layouts as data; never execute block/entity content.

Packing/index reference: the original Litematica ArrayBlockContainer and
TightLongBackedIntArray in https://github.com/maruohon/litematica/tree/ornithe/1.12.2/src/main/java/litematica/schematic/container
"""
from pathlib import Path
import gzip
import hashlib
import json
import math
import struct

HERE = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/ADMIN/AppData/Roaming/PrismLauncher/instances/Tin PLay 1.21.11 Tesst/minecraft/schematics')


def read_nbt(path):
    raw = path.read_bytes()
    data = gzip.decompress(raw) if raw[:2] == b'\x1f\x8b' else raw
    position = 0

    def take(length):
        nonlocal position
        if not 0 <= length <= len(data) - position:
            raise ValueError('Invalid NBT length')
        value = data[position:position + length]
        position += length
        return value

    def number(fmt):
        return struct.unpack('>' + fmt, take(struct.calcsize('>' + fmt)))[0]

    def string():
        return take(number('H')).decode('utf-8')

    def value(tag):
        if tag in (1, 2, 3, 4, 5, 6):
            return number({1: 'b', 2: 'h', 3: 'i', 4: 'q', 5: 'f', 6: 'd'}[tag])
        if tag == 7:
            return list(take(number('i')))
        if tag == 8:
            return string()
        if tag == 9:
            element_tag, count = number('B'), number('i')
            if not 0 <= count <= len(data):
                raise ValueError('Invalid NBT list count')
            return [value(element_tag) for _ in range(count)]
        if tag == 10:
            result = {}
            while True:
                child = number('B')
                if child == 0:
                    return result
                name = string()
                result[name] = value(child)
        if tag in (11, 12):
            count = number('i')
            if not 0 <= count <= len(data):
                raise ValueError('Invalid NBT array count')
            return [number('i' if tag == 11 else 'q') for _ in range(count)]
        raise ValueError(f'Unsupported NBT tag {tag}')

    root_tag = number('B')
    if root_tag != 10:
        raise ValueError('Schematic root must be an NBT compound')
    string()
    root = value(root_tag)
    if position != len(data):
        raise ValueError('Trailing NBT data')
    return root, hashlib.sha256(raw).hexdigest()


def decode(path):
    root, digest = read_nbt(path)
    cells = []
    regions = []
    for name, region in root['Regions'].items():
        size = [region['Size'][axis] for axis in 'xyz']
        dimensions = [abs(v) for v in size]
        minimum = [region['Position'][axis] + min(0, size[i] + 1) for i, axis in enumerate('xyz')]
        sx, sy, sz = dimensions
        volume = sx * sy * sz
        palette = region['BlockStatePalette']
        bits = max(2, (len(palette) - 1).bit_length())
        words = [v & ((1 << 64) - 1) for v in region['BlockStates']]
        if len(words) != math.ceil(volume * bits / 64):
            raise ValueError('Unexpected packed block-state length')
        count = 0
        for index in range(volume):
            start = index * bits
            word, shift = divmod(start, 64)
            packed = words[word] >> shift
            if shift + bits > 64:
                packed |= words[word + 1] << (64 - shift)
            palette_index = packed & ((1 << bits) - 1)
            state = palette[palette_index]
            block = state['Name']
            if block in ('minecraft:air', 'minecraft:cave_air', 'minecraft:void_air'):
                continue
            local = [index % sx, index // (sx * sz), (index // sx) % sz]
            mc = [local[i] + minimum[i] for i in range(3)]
            slab_type = state.get('Properties', {}).get('type') if block.endswith('_slab') else None
            if slab_type not in (None, 'bottom', 'top', 'double'):
                raise ValueError('Unsupported slab type')
            height = .5 if slab_type in ('bottom', 'top') else 1
            position = [mc[0], -mc[2], mc[1] + (.5 if slab_type == 'top' else 0)]
            cells.append({'region': name, 'index': index, 'minecraft_xyz': mc, 'blender_bottom_center': position,
                          'block_state': state, 'height_m': height, 'slab_type': slab_type})
            count += 1
        regions.append({'name': name, 'size': size, 'position': region['Position'], 'palette': palette,
                        'bits_per_entry': bits, 'volume': volume, 'nonair_count': count})
    if len(cells) != root['Metadata']['TotalBlocks']:
        raise ValueError('Decoded count differs from schematic metadata')
    return {'source_file': str(path), 'source_sha256': digest, 'version': root['Version'],
            'minecraft_data_version': root['MinecraftDataVersion'], 'metadata': root['Metadata'],
            'axis_transform': 'Blender(X,Y,Z)=(MinecraftX,-MinecraftZ,MinecraftY); rotation, no reflection',
            'unit_m': 1, 'regions': regions, 'cells': cells}


if __name__ == '__main__':
    result = {'designs': [decode(SOURCE / name) for name in ('Bush design.litematic', '111.litematic')]}
    destination = HERE / 'user_litematic_layouts_v1.json'
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))
