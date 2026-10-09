"""Read the saved World Map library in background Blender; never save source.

Run with Blender --background --factory-startup --disable-autoexec --python
scripts/export_world_map_assets.py. Pass -- --inspect for a source inventory.
"""
from pathlib import Path
import hashlib
import json
import sys
import struct
from collections import Counter

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend"
OUTPUT = ROOT / "game_mobile_3d/assets/environment/world_map_v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def specifications():
    specs = []
    for kind in ("Grass", "Dirt", "Stone"):
        for form in ("Block", "Slab"):
            specs.append((f"{kind.lower()}_{form.lower()}", [f"ENV_{kind}{form}_DI_V3"], "texture"))
    for form, prefix in (("leaf", "ENV_LeafBlock_1m_V1_"), ("leaf_slab", "ENV_LeafSlab_1x1x05m_V1_")):
        for letter in "ABC":
            core = prefix + letter
            specs.append((form + "_" + letter.lower(), [core, core + "_BushyFoliage", core + "_DenseInterior"], "leaf"))
    for color in ("White", "Blue", "Red", "Yellow"):
        specs.append(("flower_" + color.lower(), ["ENV_" + color + "FlowerPatch_1m_V1"], "linear_color"))
    specs.append(("tall_grass", ["ENV_TallGoldenGrass_1m_V1"], "linear_color"))
    specs.append(("short_grass", ["REVIEW_Original_Grass_V4"], "bend_data"))
    return specs


def inspect():
    result = []
    for filename, names, contract in specifications():
        objects = []
        for name in names:
            obj = bpy.data.objects.get(name)
            if obj is None:
                raise RuntimeError("Exact authored source is missing: " + name)
            mesh = obj.data
            objects.append({"name": name, "mesh": mesh.name,
                "location": list(obj.location), "rotation": list(obj.rotation_euler), "scale": list(obj.scale),
                "parent": obj.parent.name if obj.parent else None, "matrix_parent_inverse": [list(row) for row in obj.matrix_parent_inverse],
                "vertices": len(mesh.vertices), "polygons": len(mesh.polygons),
                "bounds": [[min(v.co[i] for v in mesh.vertices) for i in range(3)], [max(v.co[i] for v in mesh.vertices) for i in range(3)]],
                "modifiers": [{"name": m.name, "type": m.type, "viewport": m.show_viewport, "render": m.show_render} for m in obj.modifiers],
                "shape_keys": [{"name": k.name, "value": k.value} for k in mesh.shape_keys.key_blocks] if mesh.shape_keys else [],
                "colors": [{"name": a.name, "domain": a.domain, "data_type": a.data_type} for a in mesh.color_attributes],
                "uvs": [u.name for u in mesh.uv_layers],
                "materials": [{"name": m.name, "links": [[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in m.node_tree.links] if m.use_nodes else []} for m in mesh.materials],
                "custom": {k: str(v) for k,v in obj.items()}})
        result.append({"asset": filename, "contract": contract, "objects": objects})
    print("WORLD_MAP_SOURCE_INVENTORY=" + json.dumps(result))


def bounds(points):
    return [[min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)]]


def yup(vector):
    return (vector[0], vector[2], -vector[1])


def read_glb(path):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from("<4sII", raw)
    assert magic == b"glTF" and version == 2 and size == len(raw)
    length, tag = struct.unpack_from("<II", raw, 12)
    assert tag == 0x4E4F534A
    document = json.loads(raw[20:20 + length])
    binary_size, binary_tag = struct.unpack_from("<II", raw, 20 + length)
    assert binary_tag == 0x004E4942
    return document, raw[28 + length:28 + length + binary_size]


def accessor(document, binary, index):
    a = document["accessors"][index]
    view = document["bufferViews"][a["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    kind, size = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}[a["componentType"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    rows = [struct.unpack_from("<" + kind * width, binary, start + i * view.get("byteStride", width * size)) for i in range(a["count"])]
    if a.get("normalized"):
        divisor = {5121: 255, 5123: 65535}[a["componentType"]]
        rows = [tuple(v / divisor for v in row) for row in rows]
    return rows


def source_corners(mesh, contract):
    """Read Blender corners independently of glTF exporter internals."""
    uv_names = [uv.name for uv in mesh.uv_layers]
    active = mesh.uv_layers.active.name if mesh.uv_layers.active else None
    # glTF puts the material/active UV first, then retains the second wind channel.
    if active in uv_names:
        uv_names.remove(active)
        uv_names.insert(0, active)
    color = mesh.color_attributes.get("Color" if contract == "linear_color" else "GRASS_BEND_DATA")
    corners = {}
    for polygon in mesh.polygons:
        material = mesh.materials[polygon.material_index].name
        for li in polygon.loop_indices:
            vertex = mesh.loops[li].vertex_index
            row = {"POSITION": yup(mesh.vertices[vertex].co), "NORMAL": yup(mesh.corner_normals[li].vector)}
            for i, uv_name in enumerate(uv_names):
                uv = mesh.uv_layers[uv_name].data[li].uv
                row["TEXCOORD_" + str(i)] = (uv.x, 1 - uv.y)
            if contract in ("linear_color", "bend_data"):
                row["COLOR_0"] = tuple(color.data[li if color.domain == "CORNER" else vertex].color)
            corners.setdefault((material, tuple(round(v, 6) for v in row["POSITION"])), []).append(row)
    return corners


def source_image_bytes(objects):
    images = {}
    for obj in objects:
        for material in obj.data.materials:
            for node in material.node_tree.nodes:
                if node.type != "TEX_IMAGE" or node.image is None:
                    continue
                image = node.image
                if image.name in images:
                    continue
                payload = bytes(image.packed_file.data) if image.packed_file else Path(bpy.path.abspath(image.filepath)).read_bytes()
                alpha = image.pixels[3::4]
                images[image.name] = {"name": image.name, "size": list(image.size), "sha256": hashlib.sha256(payload).hexdigest(),
                                      "colorspace": image.colorspace_settings.name, "alpha_counts": dict(Counter(str(round(a, 6)) for a in alpha)),
                                      "interpolation": node.interpolation}
    return list(images.values())


def audit_asset(path, objects, contract, original_records):
    gltf, binary = read_glb(path)
    assert not any(k in gltf for k in ("animations", "skins", "cameras"))
    assert len(gltf["nodes"]) == len(gltf["meshes"]) == len(objects)
    images = source_image_bytes(objects)
    image_hashes = {image["sha256"] for image in images}
    embedded = []
    for image in gltf.get("images", []):
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        digest = hashlib.sha256(binary[start:start + view["byteLength"]]).hexdigest()
        assert digest in image_hashes, "Embedded image bytes differ from packed source"
        embedded.append({"name": image.get("name", ""), "mime_type": image["mimeType"], "sha256": digest})
    assert len(embedded) == len(images)
    for sampler in gltf.get("samplers", []):
        assert sampler["magFilter"] == 9728 and sampler["minFilter"] in (9728, 9984), "Original nearest sampler changed"
    material_records = []
    for material in gltf["materials"]:
        mode = material.get("alphaMode", "OPAQUE")
        factor = material["pbrMetallicRoughness"].get("baseColorFactor", [1, 1, 1, 1])
        if contract == "leaf":
            assert mode == "MASK" and material.get("doubleSided") is True
            assert abs(material.get("alphaCutoff", .5) - .5) < 1e-6
            expected = [.88, .88, .88, 1] if "Interior" in material["name"] else [1, 1, 1, 1]
            assert max(abs(a - b) for a, b in zip(factor, expected)) < 1e-6
        else:
            assert mode == "OPAQUE"
            if contract in ("linear_color", "bend_data"):
                assert material.get("doubleSided") is True
        material_records.append({"name": material["name"], "alpha_mode": mode, "alpha_cutoff": material.get("alphaCutoff", .5),
                                 "double_sided": material.get("doubleSided", False), "base_color_factor": factor,
                                 "base_color_texture": material["pbrMetallicRoughness"].get("baseColorTexture"),
                                 "roughness": material["pbrMetallicRoughness"].get("roughnessFactor", 1),
                                 "metallic": material["pbrMetallicRoughness"].get("metallicFactor", 1)})
    records = []
    all_points = []
    for obj in objects:
        source = obj.data
        source.calc_loop_triangles()
        corners = source_corners(source, contract)
        node = next(node for node in gltf["nodes"] if node["name"] == obj.name)
        assert node.get("translation", [0, 0, 0]) == [0, 0, 0]
        assert node.get("rotation", [0, 0, 0, 1]) == [0, 0, 0, 1]
        assert node.get("scale", [1, 1, 1]) == [1, 1, 1] and "matrix" not in node
        primitives = gltf["meshes"][node["mesh"]]["primitives"]
        assert sum(gltf["accessors"][p["indices"]]["count"] for p in primitives) == 3 * len(source.loop_triangles)
        errors = {}
        surface_counts = []
        for primitive in primitives:
            assert primitive.get("mode", 4) == 4 and not primitive.get("targets")
            attrs = {name: accessor(gltf, binary, value) for name, value in primitive["attributes"].items()}
            expected_attrs = {"POSITION", "NORMAL", *["TEXCOORD_" + str(i) for i in range(len(source.uv_layers))]}
            if contract in ("linear_color", "bend_data"):
                expected_attrs.add("COLOR_0")
            assert set(attrs) == expected_attrs, (obj.name, set(attrs), expected_attrs)
            name = gltf["materials"][primitive["material"]]["name"]
            index_rows = accessor(gltf, binary, primitive["indices"])
            assert all(0 <= row[0] < len(attrs["POSITION"]) for row in index_rows)
            triangle_count = len(index_rows) // 3
            source_count = sum(1 for tri in source.loop_triangles if source.materials[tri.material_index].name == name)
            assert triangle_count == source_count
            surface_counts.append({"material": name, "triangles": triangle_count, "vertices": len(attrs["POSITION"]), "attributes": sorted(attrs)})
            all_points.extend(attrs["POSITION"])
            for i, position in enumerate(attrs["POSITION"]):
                candidates = corners.get((name, tuple(round(v, 6) for v in position)))
                assert candidates, (obj.name, position)
                def row_error(candidate):
                    return max(abs(a - b) for attr in attrs for a, b in zip(attrs[attr][i], candidate[attr]))
                best = min(candidates, key=row_error)
                for attr in attrs:
                    error = max(abs(a - b) for a, b in zip(attrs[attr][i], best[attr]))
                    errors[attr] = max(errors.get(attr, 0), error)
                    assert error < (1.5e-4 if attr == "NORMAL" else 2e-5), (obj.name, attr, error)
        records.append({"source_object": original_records[obj.name]["source_object"], "node": obj.name,
                        "native_mesh_transform": {"translation": [0, 0, 0], "rotation_quaternion": [0, 0, 0, 1], "scale": [1, 1, 1]},
                        "source_display_transform_removed": original_records[obj.name],
                        "bounds_blender": bounds([v.co for v in source.vertices]),
                        "triangles": len(source.loop_triangles), "surfaces": surface_counts, "source_to_binary_max_error": errors})
    bb = bounds(all_points)
    assert abs(bb[0][1]) < 1e-7, "Bottom-centred asset origin must be Y=0"
    return {"file": path.name, "sha256": sha(path), "byte_length": path.stat().st_size, "contract": contract,
            "bounds_godot": bb, "dimensions_godot": [bb[1][i] - bb[0][i] for i in range(3)],
            "triangles": sum(r["triangles"] for r in records), "surface_count": sum(len(r["surfaces"]) for r in records),
            "meshes": records, "materials": material_records, "source_images": images, "embedded_images": embedded,
            "binary_corner_audit": "PASS", "native_transforms_identity": True}


def write_import(path):
    resource = "res://" + path.relative_to(ROOT / "game_mobile_3d").as_posix()
    digest = hashlib.md5(resource.encode()).hexdigest()
    imported = "res://.godot/imported/" + path.name + "-" + digest + ".scn"
    text = '''[remap]

importer="scene"
importer_version=1
type="PackedScene"
path="{imported}"

[deps]

source_file="{resource}"
dest_files=["{imported}"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/use_name_suffixes=false
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/force_disable_compression=true
animation/import=false
import_script/path="res://assets/environment/world_map_v1/native_asset_import.gd"
materials/extract=0
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=3
gltf/texture_map_mode=0
'''.format(imported=imported, resource=resource)
    path.with_suffix(path.suffix + ".import").write_text(text, encoding="utf-8")


def export_all(before):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    export_scene = bpy.data.scenes.new("WORLD_MAP_READ_ONLY_EXPORT")
    prepared = []
    for filename, names, contract in specifications():
        objects, original_records = [], {}
        for index, name in enumerate(names):
            source = bpy.data.objects.get(name)
            assert source is not None, "Exact source unavailable: " + name
            assert tuple(source.scale) == (1, 1, 1) and tuple(source.rotation_euler) == (0, 0, 0)
            if source.parent:
                assert source.parent.name == names[0] and tuple(source.location) == (0, 0, 0)
                assert source.matrix_parent_inverse == Matrix.Identity(4)
            mesh = bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph) if source.modifiers else source.data.copy()
            obj = bpy.data.objects.new(filename + ("__" + ("core", "bushy", "interior")[index] if len(names) > 1 else ""), mesh)
            export_scene.collection.objects.link(obj)
            if source.data.shape_keys:
                assert contract == "bend_data"
                rest = [v.co.copy() for v in source.data.shape_keys.key_blocks[0].data]
                obj.shape_key_clear()
                for vertex, position in zip(mesh.vertices, rest):
                    vertex.co = position
                mesh.update()
            assert not obj.data.shape_keys and not obj.modifiers and not obj.animation_data
            obj.matrix_world = Matrix.Identity(4)
            original_records[obj.name] = {"source_object": name, "source_mesh": source.data.name,
                "location": list(source.location), "rotation": list(source.rotation_euler), "scale": list(source.scale),
                "parent": source.parent.name if source.parent else None,
                "evaluated_modifiers": [m.name for m in source.modifiers],
                "shape_key_basis_used": bool(source.data.shape_keys)}
            objects.append(obj)
        prepared.append((filename, contract, objects, original_records))
    bpy.context.window.scene = export_scene
    bpy.context.view_layer.update()
    manifest = {"schema": 1, "status": "source and binary audit passed; runtime visual review is separate",
                "source_blend": SOURCE.relative_to(ROOT).as_posix(), "source_sha256_before": before,
                "blender_version": bpy.app.version_string, "metres_per_block": 1,
                "coordinate_conversion": "Blender (X,Y,Z) -> glTF/Godot (X,Z,-Y), once; every mesh node identity",
                "source_policy": "Saved blend opened in background with scripts disabled; duplicate evaluated/rest meshes only; no save or live-window operation",
                "godot_import_hook": "native_asset_import.gd",
                "godot_import_contract": "Keep texture RGB/UV/MASK, linear COLOR_0 albedo for flowers/tall grass only; short grass COLOR_0 is bend data. No lightmap unwrap, LOD generation or mesh compression. Embedded images uncompressed.",
                "assets": {}}
    for filename, contract, objects, original_records in prepared:
        for obj in export_scene.objects:
            obj.select_set(False)
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        path = OUTPUT / (filename + ".glb")
        kwargs = dict(filepath=str(path), export_format="GLB", use_selection=True, use_active_scene=True, export_yup=True,
                      export_normals=True, export_texcoords=True, export_materials="EXPORT",
                      export_animations=False, export_morph=False, export_skins=False, export_cameras=False,
                      export_lights=False, export_extras=False, export_apply=False,
                      export_vertex_color="NAME" if contract in ("linear_color", "bend_data") else "NONE",
                      export_vertex_color_name="Color" if contract == "linear_color" else "GRASS_BEND_DATA",
                      export_all_vertex_colors=False)
        bpy.ops.export_scene.gltf(**kwargs)
        manifest["assets"][filename] = audit_asset(path, objects, contract, original_records)
        write_import(path)
        print("AUDITED", filename, manifest["assets"][filename]["triangles"], "triangles")
    after = sha(SOURCE)
    assert before == after, "Saved source changed during export; do not publish the results"
    manifest.update(source_sha256_after=after, source_unchanged=True)
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("WORLD_MAP_EXPORT_PASS=" + json.dumps({"assets": len(prepared), "source_sha256": after}))


if __name__ == "__main__":
    assert bpy.app.background, "This exporter must not execute in or change the live Blender window."
    before = sha(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    if "--inspect" in sys.argv:
        inspect()
    else:
        export_all(before)
    assert sha(SOURCE) == before, "Saved source changed during read-only export."
