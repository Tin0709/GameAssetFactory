"""Deterministic descriptions of staged content, without guessing its intent."""
from collections import Counter
import io
import json
import os
from pathlib import PurePosixPath
from git_large_file_guard import LFS_POINTER


def _previous_pointer_paths(run, candidates):
    """Recognize old pointer blobs even when their attributes were removed."""
    if not candidates:
        return set()
    paths_by_oid = {}
    for record in run('ls-tree', '-r', '-z', 'HEAD').stdout.split(b'\0'):
        if not record:
            continue
        metadata, path = record.split(b'\t', 1)
        _, kind, oid = metadata.split()
        if path in candidates and kind == b'blob':
            paths_by_oid.setdefault(oid, set()).add(path)
    if not paths_by_oid:
        return set()
    sizes = run('cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)',
                data=b'\n'.join(paths_by_oid) + b'\n').stdout.splitlines()
    small = [row.split()[0] for row in sizes if row.split()[1] == b'blob' and int(row.split()[2]) <= 1024]
    if not small:
        return set()
    # Batch by object ID, never filename: unusual tabs/newlines cannot corrupt
    # the batch protocol, and large old assets are not read into memory.
    stream = io.BytesIO(run('cat-file', '--batch', data=b'\n'.join(small) + b'\n').stdout)
    result = set()
    for _ in small:
        oid, kind, size = stream.readline().split()
        data = stream.read(int(size))
        stream.read(1)
        if kind == b'blob' and LFS_POINTER.fullmatch(data):
            result.update(paths_by_oid[oid])
    return result


def _category(paths):
    paths = [PurePosixPath(path.lower()) for path in paths]
    if all('tests' in path.parts or path.name.startswith('test_') for path in paths):
        return 'test', 'test'
    if all(path.suffix in {'.md', '.rst', '.txt', '.adoc'} for path in paths):
        return 'docs', 'docs'
    if all(path.suffix in {'.blend', '.fbx', '.glb', '.gltf', '.png', '.jpg', '.jpeg',
                          '.ico', '.webp', '.gif', '.tga', '.wav', '.ogg', '.mp3',
                          '.mp4', '.zip', '.exr', '.hdr', '.obj', '.svg'} for path in paths):
        return 'assets', 'asset'
    if all(path.parts[0] == 'game_mobile_3d' for path in paths):
        return 'game', 'game'
    if all(path.suffix in {'.py', '.gd', '.sh', '.ps1', '.cmd', '.bat', '.js', '.ts', '.cs', '.cpp', '.h'} for path in paths):
        return 'chore', 'code'
    return 'chore', ''


def staged_message(run, repository, branch, stamp):
    """Return one full commit message; all stats refer to Git's staged blobs.

    Rename detection is disabled deliberately: a move is reported as an added
    path and a deleted path, matching the safety checks in the Git controller.
    LFS pointer lines are not meaningful edits to the original binary asset.
    """
    fields = run('diff', '--cached', '--name-status', '-z', '--no-renames',
                 '--no-ext-diff', '--no-textconv').stdout.split(b'\0')
    changes = [(fields[index].decode('ascii'), fields[index + 1])
               for index in range(0, len(fields) - 1, 2)]
    if not changes:
        raise ValueError('No staged changes to describe')
    paths = [path for _, path in changes]
    attrs = run('check-attr', '--cached', '-z', '--stdin', 'filter',
                data=b'\0'.join(paths) + b'\0').stdout.split(b'\0')
    lfs_paths = {attrs[index] for index in range(0, len(attrs) - 1, 3)
                 if attrs[index + 2] == b'lfs'}
    added = removed = binaries = 0
    stats = run('diff', '--cached', '--numstat', '-z', '--no-renames',
                '--no-ext-diff', '--no-textconv').stdout.split(b'\0')
    stats = [row.split(b'\t', 2) for row in filter(None, stats)]
    lfs_paths.update(_previous_pointer_paths(run, {path for plus, minus, path in stats
                                                 if path not in lfs_paths and plus != b'-' and minus != b'-'}))
    for plus, minus, path in stats:
        if path in lfs_paths or plus == b'-' or minus == b'-':
            binaries += 1
        else:
            added += int(plus)
            removed += int(minus)
    category, noun = _category([os.fsdecode(path) for path in paths])
    count = len(changes)
    kind = (noun + ' ') if noun else ''
    title = f'{category}: change {count} {kind}file' + ('s' if count != 1 else '')
    totals = Counter(status[0] for status, _ in changes)
    labels = [('A', 'Added'), ('M', 'Modified'), ('D', 'Deleted'), ('T', 'Type changed')]
    counts = [f'{label}: {totals.pop(code)}.' for code, label in labels if totals.get(code)]
    counts.extend(f'{code}: {value}.' for code, value in sorted(totals.items()))
    actions = {'A': 'Add', 'M': 'Modify', 'D': 'Delete', 'T': 'Type change'}
    lines = [' '.join(counts), f'Text lines: +{added} / -{removed}; binary files: {binaries}.', '']
    for status, path in changes:
        name = json.dumps(os.fsdecode(path), ensure_ascii=False)
        lines.append(f'- {actions.get(status[0], "Change")}: {name}')
    lines.extend(['', f'Repository: {repository}', f'Branch: {branch}', f'Checkpoint: {stamp}'])
    return title + '\n\n' + '\n'.join(lines) + '\n'
