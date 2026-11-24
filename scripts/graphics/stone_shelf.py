"""Bake the stone-shelf corner field from a map's runtime.json."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

if __package__:
    from .terrain_irradiance import Scene
else:
    from terrain_irradiance import Scene

CORNERS = np.array(((0, 0), (1, 0), (0, 1), (1, 1)))
STONE = {"stone_block", "stone_slab"}
NEUTRAL = 128


def smoothstep(first, last, values):
    t = np.clip((values - first) / (last - first), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def layout_surfaces(layout):
    occupied = {}
    for x, y, z, index in layout["cells"]:
        entry = layout["palette"][index]
        if entry["category"] != "terrain":
            continue
        bottom = round(2 * (y + entry["base_y_offset"]))
        top = bottom + round(2 * entry["height"])
        column = occupied.setdefault((x, z), {})
        column.update({height: entry["kind"] for height in range(bottom, top)})
    solids = np.array([(x, y, z) for (x, z), column in occupied.items() for y in column], dtype=int)
    shelves = [
        (x, z, max(column) + 1) for (x, z), column in occupied.items()
        if column[max(column)] in STONE
    ]
    overlapping = {xz for xz, column in occupied.items() if sum(y + 1 not in column for y in column) > 1}
    return solids, np.asarray(shelves, dtype=int).reshape(-1, 3), overlapping


def cover_at_corners(scene, shelves):
    directions = np.arange(512)
    fraction = (directions + 0.5) / len(directions)
    theta = 2 * np.pi * (directions * ((np.sqrt(5.0) - 1.0) / 2.0) + 0.021)
    sky = np.column_stack((np.sqrt(fraction) * np.cos(theta), np.sqrt(1.0 - fraction),
                           np.sqrt(fraction) * np.sin(theta)))
    xz = shelves[:, None, :2] + np.where(CORNERS > 0, 0.915, 0.085)
    y = np.broadcast_to(shelves[:, None, 2:3] * 0.5 + 0.065, (len(shelves), 4, 1))
    origins = np.concatenate((xz[..., :1], y, xz[..., 1:]), axis=-1).reshape(-1, 3) + scene.offset
    loss = np.empty(len(origins))
    for start in range(0, len(origins), 110):
        points = origins[start:start + 110]
        launch = np.repeat(points, len(sky), axis=0)
        vectors = np.tile(sky, (len(points), 1))
        ids, face = scene.trace(launch, vectors)
        hit = np.flatnonzero(ids >= 0)
        if np.any(~np.any(face[hit], axis=1)):
            raise ValueError("A stone shelf ray started inside solid terrain")
        axis = np.abs(face[hit]).argmax(axis=1)
        border = (scene.cells[ids[hit]] + (face[hit] > 0)) / scene.scale + scene.offset
        distance = np.full(len(ids), np.inf)
        distance[hit] = (border[np.arange(len(axis)), axis] - launch[hit, axis]) / vectors[hit, axis]
        coverage = 1.0 - smoothstep(1.3, 2.2, distance.astype(np.float32))
        loss[start:start + len(points)] = coverage.reshape(-1, len(sky)).mean(axis=1)
    return loss.reshape(-1, 4)


def redistribute(shelves, cover, shape, overlapping, minimum):
    x, z = (shelves[:, :2] - minimum).T
    elevation = shelves[:, 2]
    field = np.full((*shape, 4), NEUTRAL, dtype=np.uint8)
    values = np.zeros_like(cover)
    for height in np.unique(elevation):
        selected = elevation == height
        zx = z[selected], x[selected]
        valid = np.zeros(shape, dtype=np.float32)
        local = np.zeros_like(valid)
        valid[zx] = 1.0
        local[zx] = cover[selected].mean(axis=1)
        support = gaussian_filter(valid, sigma=1.15, mode="constant", truncate=2.4)[zx]
        mean = gaussian_filter(local, sigma=1.15, mode="constant", truncate=2.4)[zx] / np.maximum(support, 1.e-8)
        values[selected] = (mean[:, None] - cover[selected]) * smoothstep(.25, .60, support[:, None])
    corner_xz = shelves[:, None, :2] + CORNERS
    corner_y = np.broadcast_to(elevation[:, None, None], (*corner_xz.shape[:2], 1))
    keys = np.concatenate((corner_xz, corner_y), axis=-1)
    shared, ids = np.unique(keys.reshape(-1, 3), axis=0, return_inverse=True)
    weights = np.bincount(ids, weights=values.ravel()) / np.bincount(ids)
    protected = {(*tuple(cell[:2] + offset), cell[2]) for cell in shelves
                 if tuple(cell[:2]) in overlapping for offset in CORNERS}
    weights[np.array([tuple(row) in protected for row in shared], dtype=bool)] = 0.0
    codes = np.clip(np.rint(NEUTRAL + 127.0 * weights[ids] / 0.20), 1, 255).astype(np.uint8)
    field[z, x] = codes.reshape(-1, 4)
    return field


def bake(source, destination):
    payload = source.read_bytes()
    layout = json.loads(payload)
    minimum = np.asarray(layout["source_bounds"]["min"], dtype=int)[[0, 2]]
    maximum = np.asarray(layout["source_bounds"]["max"], dtype=int)[[0, 2]]
    extent = maximum - minimum + 1
    if np.any(extent <= 0) or np.any(extent > 4096):
        raise ValueError("Invalid horizontal bounds for a shelf texture")
    solids, shelves, overlapping = layout_surfaces(layout)
    offset = np.asarray(layout["offset"])
    if np.any(shelves[:, :2] < minimum) or np.any(shelves[:, :2] > maximum):
        raise ValueError("Stone surface lies outside the layout bounds")
    cover = cover_at_corners(Scene(solids, offset, np.zeros_like(solids)), shelves) if len(shelves) else np.empty((0, 4))
    field = redistribute(shelves, cover, tuple(extent[::-1]), overlapping, minimum)
    data = {
        "layout_sha256": sha256(payload).hexdigest(),
        "origin_xz": (minimum + offset[[0, 2]]).tolist(),
        "extent": extent.tolist(),
        "stone_shelves": len(shelves),
        "active_cells": int(np.any(field != NEUTRAL, axis=-1).sum()),
        "texture_sha256": sha256(field.tobytes()).hexdigest(),
    }
    destination.mkdir(parents=True, exist_ok=False)
    Image.fromarray(field).save(destination / "stone_shelf_corners.png")
    (destination / "stone_shelf.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Imported map runtime.json")
    parser.add_argument("output", type=Path, help="New directory for the RGBA atlas and JSON manifest")
    args = parser.parse_args()
    print(json.dumps(bake(args.source, args.output)))


if __name__ == "__main__":
    main()
