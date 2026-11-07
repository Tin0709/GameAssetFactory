"""Bake original GAF upper-sky luma accessibility from exported solid half cells.

No MD2 data or shader code is used. Requires the existing optional NumPy authoring
dependency; the playable game does not import Python or run rays.
"""
from pathlib import Path
import argparse
import json
import math
import time
import numpy as np


def directions(count):
    j = np.arange(count, dtype=float)
    y = (j + .5) / count
    angle = j * (math.pi * (3. - math.sqrt(5.)))
    radius = np.sqrt(1. - y * y)
    return np.column_stack([np.cos(angle) * radius, y, np.sin(angle) * radius])


class Source:
    def __init__(self, folder):
        folder = Path(folder)
        self.metadata = json.loads((folder / 'metadata.private.json').read_text())
        self.points = np.fromfile(folder / 'vertices.private.bin', np.float32).reshape(-1, 6)
        if len(self.points) != self.metadata['count']:
            raise ValueError('Source vertex count mismatch')
        snapped = np.round(self.points[:, :3] * 2.) * .5
        self.points[:, :3] = np.where(abs(self.points[:, :3] - snapped) < 1e-4,
                                      snapped, self.points[:, :3])
        self.offset = np.asarray(self.metadata['offset'], float)
        self.scale = np.array([1., 2., 1.])
        cells = np.asarray(self.metadata['occupied'], int)
        self.low = cells.min(0)
        self.high = cells.max(0) + 1
        self.solid = np.zeros(tuple(self.high - self.low), bool)
        self.solid[tuple((cells - self.low).T)] = True

    def hits(self, origins, directions_):
        """Exact anisotropic DDA with global-box entry and tied-axis crossings."""
        o = (np.asarray(origins, float) - self.offset) * self.scale
        d = np.broadcast_to(np.asarray(directions_, float), o.shape) * self.scale
        if not np.all(np.isfinite(o)) or not np.all(np.isfinite(d)) or np.any(np.all(d == 0., axis=1)):
            raise ValueError('Rays require finite origins and nonzero finite directions')
        a = np.divide(self.low - o, d, out=np.full_like(d, -np.inf), where=d != 0)
        b = np.divide(self.high - o, d, out=np.full_like(d, np.inf), where=d != 0)
        enter = np.maximum(np.minimum(a, b).max(1), 0.)
        leave = np.maximum(a, b).min(1)
        valid = (leave > enter) & np.all((d != 0) | ((o >= self.low) & (o < self.high)), axis=1)
        o = o + d * np.where(valid, enter + 1e-8, 0.)[:, None]
        cell = np.floor(o).astype(np.int32)
        step = np.sign(d).astype(np.int32)
        delta = np.divide(1., abs(d), out=np.full_like(d, np.inf), where=d != 0)
        tmax = np.divide(cell + (step > 0) - o, d,
                         out=np.full_like(d, np.inf), where=d != 0)
        result = np.zeros(len(o), bool)
        active = np.flatnonzero(valid & np.all((cell >= self.low) & (cell < self.high), axis=1))
        while len(active):
            occupied = self.solid[tuple((cell[active] - self.low).T)]
            result[active[occupied]] = True
            active = active[~occupied]
            if not len(active):
                break
            axes = tmax[active] <= tmax[active].min(1)[:, None] + 1e-12
            cell[active] += step[active] * axes
            tmax[active] = np.where(axes, tmax[active] + delta[active], tmax[active])
            c = cell[active]
            active = active[np.all((c >= self.low) & (c < self.high), axis=1)]
        return result

    def evaluate(self, points, rays=1024):
        dirs = directions(rays)
        rgb = np.asarray(self.metadata['ambient_srgb'], float)
        linear = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
        luma = np.array([.2126, .7152, .0722])
        vertical = float((linear * np.array([.15, .25, .45])) @ luma / (linear @ luma))
        sky = 1. + vertical * dirs[:, 1] + .18 * (dirs[:, 0] * .616 - dirs[:, 2] * .788)
        values = np.ones(len(points), np.float32)
        for first in range(0, len(points), 256):
            p = points[first:first + 256]
            normal = p[:, 3:]
            occupied = self.hits(np.repeat(p[:, :3] + normal * .01, rays, axis=0),
                                 np.tile(dirs, (len(p), 1))).reshape(len(p), rays)
            weight = np.maximum(normal @ dirs.T, 0.) * sky
            denominator = 1. + (2. / 3.) * .18 * (normal[:, 0] * .616 - normal[:, 2] * .788)
            values[first:first + len(p)] = np.clip(
                1. - 2. * np.mean(occupied * weight, axis=1) / denominator, 0., 1.)
        return values


def bake(source, output, rays):
    if rays < 64:
        raise ValueError('Use at least64 hemisphere samples')
    output = Path(output)
    output.mkdir()  # Refuse completed outputs.
    start = time.monotonic()
    selected = np.abs(source.points[:, 4]) < .1
    unique, inverse = np.unique(source.points[selected], axis=0, return_inverse=True)
    values = np.ones(len(source.points), np.float32)
    values[selected] = source.evaluate(unique, rays)[inverse]
    values.tofile(output / 'visibility.private.bin')
    metadata = {key: source.metadata[key] for key in ('rows', 'source_runtime_sha256', 'ambient_srgb')}
    # Triangle indices are an authoring diagnostic, not runtime cache payload.
    metadata['rows'] = [{key: value for key, value in row.items() if key != 'indices'}
                        for row in metadata['rows']]
    metadata.update(rays=rays, full_vertices=len(values), unique_vertical_vertices=len(unique),
                    seconds=time.monotonic() - start, scope='Original static upper-sky luma visibility; not MD2 GI')
    (output / 'metadata.private.json').write_text(json.dumps(metadata, indent=2))
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--rays', default=1024, type=int)
    args = parser.parse_args()
    print(json.dumps({key: value for key, value in bake(Source(args.source), args.output, args.rays).items()
                      if key != 'rows'}))
