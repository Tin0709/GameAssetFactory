"""Import World Map as exact metre-grid data, never executing NBT content.

The existing project NBT reader is reused. Packed values are decoded twice by
independent word-shift and bit-string methods before any output is written.
Cells retain Minecraft integer coordinates; Godot applies only ``offset`` and
adds 0.5 to X/Z when placing bottom-centred authored assets.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil


REPO = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path("C:/Users/ADMIN/AppData/Roaming/PrismLauncher/instances/Tin PLay 1.21.11 Tesst/minecraft/schematics/World Map.litematic")
DEFAULT_OUTPUT = REPO / "game_mobile_3d/assets/maps/world_map"
AIR = {"minecraft:air", "minecraft:cave_air", "minecraft:void_air"}
MASK64 = (1 << 64) - 1
FULL_BLOCKS = {"stone": "stone_block", "dirt": "dirt_block", "coarse_dirt": "dirt_block",
               "grass_block": "grass_block"}
SLABS = {"warped_slab": "grass_slab", "granite_slab": "dirt_slab", "stone_slab": "stone_slab",
         "oak_slab": "leaf_slab"}
PLANTS = {"short_grass": "short_grass", "dandelion": "flower_yellow", "azure_bluet": "flower_white",
          "oxeye_daisy": "flower_white", "cornflower": "flower_blue", "poppy": "flower_red"}


def read_source(path):
    reader_path = REPO / "blender/environment/studies/dungeons_ground_style_v2/read_user_litematic_layouts_v1.py"
    spec = importlib.util.spec_from_file_location("existing_litematic_reader", reader_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.read_nbt(Path(path))


def unpack_indices(words, bits, volume):
    """Litematica entries are contiguous and may straddle signed 64-bit words."""
    if bits < 2 or volume < 0 or len(words) != (volume * bits + 63) // 64:
        raise ValueError("Unexpected packed block-state length or bit width")
    unsigned = [word & MASK64 for word in words]
    mask = (1 << bits) - 1
    indices = []
    for index in range(volume):
        word, shift = divmod(index * bits, 64)
        value = unsigned[word] >> shift
        if shift + bits > 64:
            value |= unsigned[word + 1] << (64 - shift)
        indices.append(value & mask)
    return indices


def unpack_reference(words, bits, volume):
    """Independent audit: concatenate each word's least-significant bit first."""
    if bits < 2 or volume < 0 or len(words) != (volume * bits + 63) // 64:
        raise ValueError("Unexpected reference packed length or bit width")
    bit_string = "".join(format(word & MASK64, "064b")[::-1] for word in words)
    return [int(bit_string[start:start + bits][::-1], 2) for start in range(0, volume * bits, bits)]


def map_state(state):
    """Reject states whose visible meaning the authored asset mapping cannot keep."""
    name = state.get("Name", "")
    if not name.startswith("minecraft:") or set(state) - {"Name", "Properties"}:
        raise ValueError(f"Unsupported block state: {state}")
    short = name.removeprefix("minecraft:")
    props = state.get("Properties", {})
    allowed = {}
    height, base = 1, 0
    if short in FULL_BLOCKS:
        kind, category = FULL_BLOCKS[short], "terrain"
        if short == "grass_block":
            allowed = {"snowy": {"false"}}
    elif short in SLABS:
        kind = SLABS[short]
        category = "leaf" if short == "oak_slab" else "terrain"
        allowed = {"type": {"bottom", "top", "double"}, "waterlogged": {"false"}}
        slab_type = props.get("type")
        if slab_type not in allowed["type"]:
            raise ValueError(f"Unsupported slab state: {state}")
        height = 1 if slab_type == "double" else .5
        base = .5 if slab_type == "top" else 0
        if slab_type == "double":
            kind = {"grass_slab": "grass_block", "dirt_slab": "dirt_block",
                    "stone_slab": "stone_block", "leaf_slab": "leaf"}[kind]
    elif short == "oak_leaves":
        kind, category = "leaf", "leaf"
        allowed = {"distance": {str(i) for i in range(1, 8)}, "persistent": {"true", "false"},
                   "waterlogged": {"false"}}
    elif short in PLANTS:
        kind, category = PLANTS[short], "plant"
    elif short == "tall_grass":
        allowed = {"half": {"lower", "upper"}}
        if props.get("half") not in allowed["half"]:
            raise ValueError(f"Unsupported tall-grass state: {state}")
        kind, category = ("tall_grass", "plant") if props["half"] == "lower" else ("tall_grass_upper", "paired_upper")
    elif short == "red_wool":
        kind, category = "boundary_marker", "marker"
    else:
        raise ValueError(f"Unsupported block state: {state}")
    if any(key not in allowed or value not in allowed[key] for key, value in props.items()):
        raise ValueError(f"Unsupported block properties: {state}")
    return {"state": copy.deepcopy(state), "kind": kind, "category": category,
            "height": height, "base_y_offset": base}


def decode_regions(root):
    palette, global_indices, cells, occupied, regions = [], {}, [], {}, []
    minimum, maximum = [None] * 3, [None] * 3
    if not root.get("Regions"):
        raise ValueError("Schematic contains no regions")
    for region_name, region in root["Regions"].items():
        size = [region["Size"][axis] for axis in "xyz"]
        if any(not isinstance(value, int) or value == 0 for value in size):
            raise ValueError(f"Invalid region dimensions: {size}")
        position = [region["Position"][axis] for axis in "xyz"]
        dimensions = [abs(value) for value in size]
        low = [position[i] + min(0, size[i] + 1) for i in range(3)]
        high = [low[i] + dimensions[i] - 1 for i in range(3)]
        for axis in range(3):
            minimum[axis] = low[axis] if minimum[axis] is None else min(minimum[axis], low[axis])
            maximum[axis] = high[axis] if maximum[axis] is None else max(maximum[axis], high[axis])
        sx, sy, sz = dimensions
        volume = sx * sy * sz
        local_palette = region["BlockStatePalette"]
        if not local_palette:
            raise ValueError("Empty block-state palette")
        palette_lookup = []
        for state in local_palette:
            if state.get("Name") in AIR:
                if set(state) != {"Name"}:
                    raise ValueError(f"Unsupported air state: {state}")
                palette_lookup.append(None)
                continue
            mapped = map_state(state)
            key = json.dumps(state, sort_keys=True, separators=(",", ":"))
            if key not in global_indices:
                global_indices[key] = len(palette)
                palette.append(mapped)
            palette_lookup.append(global_indices[key])
        bits = max(2, (len(local_palette) - 1).bit_length())
        indices = unpack_indices(region["BlockStates"], bits, volume)
        if indices != unpack_reference(region["BlockStates"], bits, volume):
            raise ValueError(f"Independent unpack mismatch in {region_name}")
        nonair_count = 0
        for index, local_id in enumerate(indices):
            if local_id >= len(local_palette):
                raise ValueError(f"Block-state index outside palette in {region_name} at {index}: {local_id}")
            global_id = palette_lookup[local_id]
            if global_id is None:
                continue
            # Signed size changes the region's minimum, never storage-axis order.
            coord = (index % sx + low[0], index // (sx * sz) + low[1], (index // sx) % sz + low[2])
            if coord in occupied:
                raise ValueError(f"Non-air region overlap/duplicate/conflict at {coord}: {occupied[coord]} and {region_name}")
            occupied[coord] = region_name
            cells.append([*coord, global_id])
            nonair_count += 1
        regions.append({"name": region_name, "position": position, "signed_size": size,
                        "min": low, "max": high, "volume": volume, "bits_per_entry": bits,
                        "nonair_count": nonair_count, "source_palette": local_palette,
                        "ignored_entity_count": len(region.get("Entities", [])),
                        "ignored_block_entity_count": len(region.get("TileEntities", []))})
    totals = {"RegionCount": len(regions), "TotalVolume": sum(region["volume"] for region in regions),
              "TotalBlocks": len(cells)}
    for key, actual in totals.items():
        if key in root.get("Metadata", {}) and root["Metadata"][key] != actual:
            raise ValueError(f"Metadata {key}={root['Metadata'][key]} differs from decoded {actual}")
    return {"palette": palette, "cells": sorted(cells), "regions": regions,
            "source_bounds": {"min": minimum, "max": maximum}, "totals": totals,
            "independent_unpack_verified": True}


def validate_tall_pairs(cells, palette):
    by_coord = {tuple(cell[:3]): palette[cell[3]] for cell in cells}
    pairs = 0
    for (x, y, z), entry in by_coord.items():
        if entry["kind"] not in {"tall_grass", "tall_grass_upper"}:
            continue
        lower = entry["kind"] == "tall_grass"
        partner = by_coord.get((x, y + (1 if lower else -1), z), {})
        expected = "tall_grass_upper" if lower else "tall_grass"
        if partner.get("kind") != expected:
            raise ValueError(f"Unpaired tall-grass {'lower' if lower else 'upper'} at {(x, y, z)}")
        pairs += int(lower)
    return pairs


def derive_border(cells, palette, source_bounds):
    markers = [tuple(cell[:3]) for cell in cells if palette[cell[3]]["category"] == "marker"]
    if not markers:
        raise ValueError("No red-wool boundary markers")
    heights = {cell[1] for cell in markers}
    if len(heights) != 1:
        raise ValueError("Boundary markers span more than one height")
    marker_y = next(iter(heights))
    x0, x1 = min(cell[0] for cell in markers), max(cell[0] for cell in markers)
    z0, z1 = min(cell[2] for cell in markers), max(cell[2] for cell in markers)
    if (x1 - x0 + 1, z1 - z0 + 1) != (100, 100):
        raise ValueError("Boundary marker outer extents must be exactly 100 by 100 metres")
    expected = {(x, marker_y, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)
                if x in (x0, x1) or z in (z0, z1)}
    if set(markers) != expected or len(markers) != len(expected):
        raise ValueError("Boundary markers do not form a complete, unique rectangular perimeter")
    offset = [-(x0 + x1 + 1) // 2, 0, -(z0 + z1 + 1) // 2]
    solids = [(cell, palette[cell[3]]) for cell in cells if palette[cell[3]]["category"] in {"terrain", "leaf"}]
    lowest = min([source_bounds["min"][1]] + [cell[1] + entry["base_y_offset"] for cell, entry in solids])
    highest = max([source_bounds["max"][1] + 1] +
                  [cell[1] + entry["base_y_offset"] + entry["height"] for cell, entry in solids])
    return {"min": [-50, lowest - 2, -50], "max": [50, highest + 8, 50],
            "source_min": [x0, marker_y, z0], "source_max": [x1, marker_y, z1],
            "marker_count": len(markers)}, offset


def terrain_face_audit(cells, palette):
    """Exact exposed area from 1 x 0.5 x 1m terrain occupancy, including bottoms.

    Leaves are alpha cutouts and do not occlude opaque terrain. No chunk partition
    is involved, so this reference catches faces accidentally hidden at seams.
    Counts describe half-height surface patches, not a renderer's quad merging.
    """
    voxels = {}
    for x, y, z, palette_id in cells:
        entry = palette[palette_id]
        if entry["category"] != "terrain":
            continue
        base = int(2 * (y + entry["base_y_offset"]))
        for half_y in range(base, base + int(2 * entry["height"])):
            voxels[(x, half_y, z)] = entry["kind"]
    directions = {"neg_x": (-1, 0, 0), "pos_x": (1, 0, 0), "neg_y": (0, -1, 0),
                  "pos_y": (0, 1, 0), "neg_z": (0, 0, -1), "pos_z": (0, 0, 1)}
    counts = {name: 0 for name in directions}
    by_kind = {}
    for (x, half_y, z), kind in voxels.items():
        areas = by_kind.setdefault(kind, {name: 0 for name in directions})
        for name, (dx, dy, dz) in directions.items():
            if (x + dx, half_y + dy, z + dz) not in voxels:
                counts[name] += 1
                areas[name] += 1 if dy else .5
    area = {name: count * (1 if name.endswith("y") else .5) for name, count in counts.items()}
    return {"half_voxel_count": len(voxels), "exposed_patch_counts": counts, "area_m2": area,
            "expected_area": area,
            "total_area_m2": sum(area.values()), "area_m2_by_kind": by_kind,
            "includes_bottom_faces": True, "leaf_occludes_terrain": False,
            "method": "independent global 1 x 0.5 x 1 metre occupancy; horizontal faces 1m2, vertical patches 0.5m2"}


def centre_ground_candidates(cells, palette, offset):
    """Near-centre terrain surfaces with two metres of solid-free headroom."""
    columns = {}
    for x, y, z, palette_id in cells:
        entry = palette[palette_id]
        if entry["category"] in {"terrain", "leaf"}:
            columns.setdefault((x, z), []).append((y + entry["base_y_offset"], entry["height"], entry["category"]))
    candidates = []
    for (x, z), spans in columns.items():
        world_x, world_z = x + offset[0] + .5, z + offset[2] + .5
        distance = world_x * world_x + world_z * world_z
        if distance > 36:
            continue
        for base, height, category in spans:
            if category != "terrain":
                continue
            top = base + height
            if any(other_base < top + 2 and other_base + other_height > top for other_base, other_height, _ in spans):
                continue
            candidates.append({"source_cell_xz": [x, z], "ground_y": top,
                               "world_feet": [world_x, top + offset[1], world_z], "centre_distance_squared": distance})
    return sorted(candidates, key=lambda row: (row["centre_distance_squared"], -row["ground_y"], row["source_cell_xz"]))[:16]


def import_source(source, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    root, source_hash = read_source(source)
    decoded = decode_regions(root)
    cells, palette = decoded["cells"], decoded["palette"]
    pair_count = validate_tall_pairs(cells, palette)
    border, offset = derive_border(cells, palette, decoded["source_bounds"])
    runtime = {"schema_version": 1, "source_sha256": source_hash, "source_bounds": decoded["source_bounds"],
               "offset": offset, "border": border, "palette": palette, "cells": cells}
    counts = Counter(cell[3] for cell in cells)
    kind_counts = Counter()
    category_counts = Counter()
    for palette_id, count in counts.items():
        kind_counts[palette[palette_id]["kind"]] += count
        category_counts[palette[palette_id]["category"]] += count
    outside = sum(not (border["source_min"][0] <= cell[0] <= border["source_max"][0] and
                       border["source_min"][2] <= cell[2] <= border["source_max"][2]) for cell in cells)
    runtime_bytes = (json.dumps(runtime, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
    manifest = {
        "schema_version": 1, "source_file": str(source), "copied_source_file": "World Map.litematic",
        "source_sha256": source_hash, "runtime_sha256": hashlib.sha256(runtime_bytes).hexdigest(),
        "source_version": root.get("Version"), "minecraft_data_version": root.get("MinecraftDataVersion"),
        "source_metadata": root.get("Metadata", {}), "decoded_totals": decoded["totals"],
        "source_bounds": decoded["source_bounds"],
        "occupied_bounds": {"min": [min(cell[i] for cell in cells) for i in range(3)],
                            "max": [max(cell[i] for cell in cells) for i in range(3)]},
        "regions": decoded["regions"], "unit_m": 1,
        "coordinate_contract": "Source cells are integer minimum corners. Godot cell corner = source + offset; bottom-centred asset = source + offset + (0.5, base_y_offset, 0.5). No rotation/reflection/scaling.",
        "offset": offset, "source_origin_in_godot": offset, "border": border,
        "border_validation": {"complete_perimeter": True, "unique_markers": True, "single_height": True,
                              "outer_face_width_m": 100, "outer_face_depth_m": 100,
                              "vertical_clearance_above_source_m": 8, "extends_below_source_m": 2},
        "independent_unpack_verified": decoded["independent_unpack_verified"],
        "unsupported": [], "duplicate_nonair_cells": 0, "tall_grass_pairs": pair_count,
        "nonair_outside_border": outside, "counts_by_kind": dict(sorted(kind_counts.items())),
        "counts_by_category": dict(sorted(category_counts.items())),
        "state_mapping": [{"palette_index": i, **entry, "source_count": counts[i]} for i, entry in enumerate(palette)],
        "expected_terrain_faces": terrain_face_audit(cells, palette),
        "centre_ground_candidates": centre_ground_candidates(cells, palette, offset),
    }
    # Complete validation before making a package, and preserve the original bytes.
    output.mkdir(parents=True, exist_ok=True)
    destination = output / "World Map.litematic"
    if source != destination:
        shutil.copyfile(source, destination)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != source_hash:
        raise ValueError("Copied schematic hash differs from source")
    (output / "runtime.json").write_bytes(runtime_bytes)
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return runtime, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    runtime, manifest = import_source(args.source, args.output)
    print(json.dumps({"output": str(args.output), "source_sha256": runtime["source_sha256"],
                      "cells": len(runtime["cells"]), "border": runtime["border"],
                      "counts_by_kind": manifest["counts_by_kind"],
                      "terrain_area_m2": manifest["expected_terrain_faces"]["area_m2"],
                      "centre_ground_candidates": manifest["centre_ground_candidates"][:4]}, indent=2))


if __name__ == "__main__":
    main()
