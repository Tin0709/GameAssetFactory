"""Behavioral fixtures for exact schematic decoding and geometry audit."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("import_world_map", REPO / "scripts/import_world_map.py")
if SPEC.origin and Path(SPEC.origin).exists():
    importer = importlib.util.module_from_spec(SPEC)
    SPEC.loader.exec_module(importer)
else:
    importer = None


def state(name, **properties):
    result = {"Name": "minecraft:" + name}
    if properties:
        result["Properties"] = properties
    return result


def packed_region(size, position, palette, indices):
    # Fixture writer deliberately uses a single integer, not the decoder's
    # word-boundary extraction algorithm.
    bits = max(2, (len(palette) - 1).bit_length())
    packed = sum(value << (bits * index) for index, value in enumerate(indices))
    count = (len(indices) * bits + 63) // 64
    words = [(packed >> (64 * index)) & ((1 << 64) - 1) for index in range(count)]
    words = [word - (1 << 64) if word >= (1 << 63) else word for word in words]
    return {
        "Size": dict(zip("xyz", size)), "Position": dict(zip("xyz", position)),
        "BlockStatePalette": palette, "BlockStates": words,
    }


def root_with(*regions):
    return {"Regions": {f"region_{i}": region for i, region in enumerate(regions)}}


class ImportWorldMapTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(importer, "The exact World Map importer has not been implemented")

    def test_signed_extents_translate_without_mirroring_and_keep_axis_order(self):
        # At X=8..10, Y=19..20, Z=30..31, X varies first, then Z, then Y.
        region = packed_region((-3, -2, 2), (10, 20, 30),
                               [state("air"), state("stone"), state("dirt")],
                               [1, 0, 2, 0, 0, 0, 0, 2, 0, 1, 0, 0])
        result = importer.decode_regions(root_with(region))
        kinds = {tuple(cell[:3]): result["palette"][cell[3]]["kind"] for cell in result["cells"]}
        self.assertEqual(kinds, {(8, 19, 30): "stone_block", (10, 19, 30): "dirt_block",
                                 (9, 20, 30): "dirt_block", (8, 20, 31): "stone_block"})
        self.assertEqual(result["source_bounds"], {"min": [8, 19, 30], "max": [10, 20, 31]})

    def test_cross_word_entry_keeps_the_high_bit_of_a_signed_long(self):
        # Entry 12 begins at bit 60: its fifth bit belongs to the next word.
        words = [-1152921504606846976, 1]
        expected = [0] * 12 + [31]
        self.assertEqual(importer.unpack_indices(words, 5, 13), expected)
        self.assertEqual(importer.unpack_reference(words, 5, 13), expected)

    def test_invalid_packing_and_out_of_palette_values_fail(self):
        with self.assertRaisesRegex(ValueError, "length"):
            importer.unpack_indices([0], 5, 13)
        region = packed_region((1, 1, 1), (0, 0, 0), [state("air"), state("stone")], [3])
        with self.assertRaisesRegex(ValueError, "palette"):
            importer.decode_regions(root_with(region))

    def test_top_bottom_and_double_slabs_preserve_vertical_occupancy(self):
        cases = [("bottom", .5, 0, "grass_slab"), ("top", .5, .5, "grass_slab"), ("double", 1, 0, "grass_block")]
        for slab_type, height, base, kind in cases:
            with self.subTest(slab_type=slab_type):
                result = importer.map_state(state("warped_slab", type=slab_type, waterlogged="false"))
                self.assertEqual((result["kind"], result["category"], result["height"], result["base_y_offset"]),
                                 (kind, "terrain", height, base))
        leaf = importer.map_state(state("oak_slab", type="top", waterlogged="false"))
        self.assertEqual((leaf["category"], leaf["height"], leaf["base_y_offset"]), ("leaf", .5, .5))
        for block, expected in (("granite_slab", "dirt_block"), ("stone_slab", "stone_block"), ("oak_slab", "leaf")):
            self.assertEqual(importer.map_state(state(block, type="double", waterlogged="false"))["kind"], expected)

    def test_unknown_or_unrepresented_state_does_not_silently_disappear(self):
        for block in (state("diamond_block"), state("grass_block", snowy="true"),
                      state("oak_slab", type="bottom", waterlogged="true"),
                      state("stone", unexpected="true")):
            with self.subTest(block=block), self.assertRaisesRegex(ValueError, "Unsupported"):
                importer.map_state(block)

    def test_overlapping_nonair_regions_fail_for_duplicates_and_conflicts(self):
        stone = packed_region((1, 1, 1), (5, 6, 7), [state("air"), state("stone")], [1])
        dirt = packed_region((1, 1, 1), (5, 6, 7), [state("air"), state("dirt")], [1])
        for other in (stone, dirt):
            with self.subTest(other=other), self.assertRaisesRegex(ValueError, "overlap|duplicate|conflict"):
                importer.decode_regions(root_with(stone, other))

    def test_tall_grass_requires_matching_upper_and_lower_cells(self):
        palette = [state("air"), state("tall_grass", half="lower"), state("tall_grass", half="upper")]
        paired = importer.decode_regions(root_with(packed_region((1, 2, 1), (0, 4, 0), palette, [1, 2])))
        self.assertEqual(importer.validate_tall_pairs(paired["cells"], paired["palette"]), 1)
        for indices in ([1, 0], [0, 2], [2, 1]):
            broken = importer.decode_regions(root_with(packed_region((1, 2, 1), (0, 4, 0), palette, indices)))
            with self.subTest(indices=indices), self.assertRaisesRegex(ValueError, "tall.grass"):
                importer.validate_tall_pairs(broken["cells"], broken["palette"])

    def test_border_requires_complete_single_height_ring_and_uses_outer_faces(self):
        palette = [importer.map_state(state("red_wool")), importer.map_state(state("stone"))]
        ring = [[x, 37, z, 0] for x in range(27, 127) for z in range(6, 106)
                if x in (27, 126) or z in (6, 105)]
        cells = ring + [[0, 0, 0, 1], [136, 53, 109, 1]]
        border, offset = importer.derive_border(cells, palette, {"min": [0, 0, 0], "max": [136, 53, 109]})
        self.assertEqual(offset, [-77, 0, -56])
        self.assertEqual(border["source_min"], [27, 37, 6])
        self.assertEqual(border["source_max"], [126, 37, 105])
        self.assertEqual(border["marker_count"], 396)
        self.assertEqual((border["min"][0], border["min"][2], border["max"][0], border["max"][2]),
                         (-50, -50, 50, 50))
        self.assertLessEqual(border["min"][1], -2)
        self.assertGreaterEqual(border["max"][1], 62)
        for bad in (ring[1:], ring + [[50, 37, 50, 0]], [[27, 38, 6, 0]] + ring[1:]):
            with self.assertRaisesRegex(ValueError, "marker|perimeter|height"):
                importer.derive_border(bad, palette, {"min": [0, 0, 0], "max": [136, 53, 109]})

    def test_half_height_face_audit_retains_uncovered_neighbour_face(self):
        palette = [importer.map_state(state("stone")),
                   importer.map_state(state("stone_slab", type="bottom", waterlogged="false"))]
        # Across a 10m chunk boundary: full cube next to a bottom half slab.
        audit = importer.terrain_face_audit([[9, 0, 0, 0], [10, 0, 0, 1]], palette)
        self.assertEqual(audit["area_m2"], {"neg_x": 1, "pos_x": 1, "neg_y": 2,
                                              "pos_y": 2, "neg_z": 1.5, "pos_z": 1.5})
        self.assertEqual(audit["total_area_m2"], 9)
        self.assertEqual(audit["half_voxel_count"], 3)

    def test_half_height_audit_does_not_emit_internal_horizontal_faces(self):
        palette = [importer.map_state(state("stone")),
                   importer.map_state(state("stone_slab", type="bottom", waterlogged="false")),
                   importer.map_state(state("stone_slab", type="top", waterlogged="false"))]
        fixtures = [([[0, 0, 0, 0]], 6), ([[0, 0, 0, 1]], 4),
                    ([[0, 0, 0, 0], [0, 1, 0, 0]], 10),
                    ([[9, 0, 0, 0], [10, 0, 0, 2]], 9),
                    ([[0, 0, 0, 2], [0, 1, 0, 1]], 6)]
        for cells, expected_area in fixtures:
            with self.subTest(cells=cells):
                self.assertEqual(importer.terrain_face_audit(cells, palette)["total_area_m2"], expected_area)

    def test_metadata_count_mismatch_fails(self):
        root = root_with(packed_region((1, 1, 1), (0, 0, 0), [state("air"), state("stone")], [1]))
        root["Metadata"] = {"TotalBlocks": 2}
        with self.assertRaisesRegex(ValueError, "TotalBlocks"):
            importer.decode_regions(root)

    def test_real_source_package_preserves_cells_states_hashes_and_scenery(self):
        source = REPO / "game_mobile_3d/assets/maps/world_map/World Map.litematic"
        if not source.exists():
            source = Path("C:/Users/ADMIN/AppData/Roaming/PrismLauncher/instances/Tin PLay 1.21.11 Tesst/minecraft/schematics/World Map.litematic")
        with tempfile.TemporaryDirectory() as temporary:
            runtime, manifest = importer.import_source(source, Path(temporary))
            self.assertEqual(len(runtime["cells"]), 42996)
            self.assertEqual(runtime["source_sha256"], "055e5e363c65fd6380fb452347279d23dc7780b977773fba700afdf256dad5ae")
            self.assertEqual(runtime["offset"], [-77, 0, -56])
            self.assertEqual(runtime["cells"], sorted(runtime["cells"]))
            self.assertEqual(len({tuple(cell[:3]) for cell in runtime["cells"]}), 42996)
            self.assertTrue(any(cell[0] < 27 or cell[0] > 126 or cell[2] < 6 or cell[2] > 105
                                for cell in runtime["cells"]))
            self.assertEqual(manifest["unsupported"], [])
            self.assertEqual(sum(manifest["counts_by_kind"].values()), 42996)
            self.assertEqual(manifest["counts_by_kind"]["tall_grass"], 363)
            self.assertEqual(manifest["tall_grass_pairs"], 363)
            self.assertTrue(manifest["independent_unpack_verified"])
            self.assertEqual((Path(temporary) / "World Map.litematic").read_bytes(), source.read_bytes())
            saved = json.loads((Path(temporary) / "runtime.json").read_text(encoding="utf-8"))
            self.assertEqual(saved, runtime)
            saved_hash = hashlib.sha256((Path(temporary) / "runtime.json").read_bytes()).hexdigest()
            self.assertEqual(manifest["runtime_sha256"], saved_hash)
            # Compare every original coordinate and full NBT state against the
            # independently established pre-existing reader, not our helpers.
            reader_path = REPO / "blender/environment/studies/dungeons_ground_style_v2/read_user_litematic_layouts_v1.py"
            reader_spec = importlib.util.spec_from_file_location("old_reader_audit", reader_path)
            reader = importlib.util.module_from_spec(reader_spec)
            reader_spec.loader.exec_module(reader)
            original = reader.decode(source)
            original_cells = {tuple(cell["minecraft_xyz"]): cell["block_state"] for cell in original["cells"]}
            runtime_cells = {tuple(cell[:3]): runtime["palette"][cell[3]]["state"] for cell in runtime["cells"]}
            self.assertEqual(runtime_cells, original_cells)


if __name__ == "__main__":
    unittest.main()
