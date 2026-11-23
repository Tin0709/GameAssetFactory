import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

HORIZONTAL_STEP = 1.25
VERTICAL_STEP = .75
AZIMUTHS = 16
DISTANCES = np.array([.6, 1.1, 1.7, 2.5, 3.5, 5., 7., 9.5, 12.])
PAD = 13.

def surface_grid(data):
    blocks = [row for row in data["cells"] if data["palette"][row[3]]["category"] == "terrain"]
    if not blocks:
        raise ValueError("Layout has no solid terrain")
    cells = np.asarray(blocks, dtype=np.int32)
    left, near = cells[:, [0, 2]].min(axis=0)
    right, far = cells[:, [0, 2]].max(axis=0)
    shape = (far-near+1, right-left+1)
    tops = np.array([float(p.get("height", 1)) + float(p.get("base_y_offset", 0)) for p in data["palette"]])
    y = cells[:, 1] + tops[cells[:, 3]]
    grid = np.full(shape, -1e5, dtype=np.float32)
    np.maximum.at(grid, (cells[:, 2] - near, cells[:, 0] - left), y)
    return grid, (int(left), int(near)), (float(y.min()), float(y.max()))

def stack_sky(grid, start, ground_y):
    x0, z0 = start
    y0, y1 = ground_y
    x = np.arange(x0-PAD, x0+grid.shape[1]+PAD+HORIZONTAL_STEP, HORIZONTAL_STEP, dtype=np.float32)
    z = np.arange(z0-PAD, z0+grid.shape[0]+PAD+HORIZONTAL_STEP, HORIZONTAL_STEP, dtype=np.float32)
    ys = np.arange(y0-1.5, y1+1.5+VERTICAL_STEP, VERTICAL_STEP, dtype=np.float32)
    xx, zz = np.meshgrid(x, z)
    blocked = np.zeros((ys.size, *xx.shape), dtype=np.float32)
    for i in range(AZIMUTHS):
        phi = 2 * math.pi * (i + .25) / AZIMUTHS
        slopes = np.zeros_like(blocked)
        for t in DISTANCES:
            ix = np.floor(xx + t*math.cos(phi)).astype(np.int32) - x0
            iz = np.floor(zz + t*math.sin(phi)).astype(np.int32) - z0
            inside = (ix >= 0) & (ix < grid.shape[1]) & (iz >= 0) & (iz < grid.shape[0])
            height = np.where(inside, grid[iz.clip(0,grid.shape[0]-1), ix.clip(0,grid.shape[1]-1)], -1e5)
            slope = (height[None,:,:] - ys[:,None,None]) / t
            np.maximum(slopes, slope, out=slopes)
        blocked += slopes / np.sqrt(1 + slopes**2)
    sky = np.clip(1 - blocked/AZIMUTHS, 0, 1)
    # ImageTexture3D consumes one data plane per Z coordinate.
    # The shader squares this R8 quantity to recover hemispherical visibility.
    image = np.rint(np.sqrt(sky.transpose(1,0,2)) * 255).astype(np.uint8)
    return image, [float(x[0]), float(ys[0]), float(z[0])]

def main():
    cli = argparse.ArgumentParser(description="Bake visible upper hemisphere from the map's terrain height field.")
    cli.add_argument("layout", type=Path)
    cli.add_argument("output", type=Path)
    config = cli.parse_args()
    raw = config.layout.read_bytes()
    data = json.loads(raw)
    terrain, start, heights = surface_grid(data)
    image, origin = stack_sky(terrain, start, heights)
    payload = image.tobytes()
    config.output.with_suffix(".r8").write_bytes(payload)
    meta = {
        "layout_sha256": hashlib.sha256(raw).hexdigest(),
        "payload_sha256": hashlib.sha256(payload).hexdigest(),
        "origin": [i+j for i,j in zip(origin,data["offset"])],
        "dimensions": list(reversed(image.shape)),
        "spacing": [HORIZONTAL_STEP, VERTICAL_STEP, HORIZONTAL_STEP],
        "bytes": len(payload),
        "nonwhite_fraction": float((image < 255).mean())
    }
    config.output.with_suffix(".json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
    print(json.dumps(meta))

if __name__ == "__main__":
    main()

