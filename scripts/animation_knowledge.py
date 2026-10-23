#!/usr/bin/env python3
"""Read-only animation documentation routes and pinned source verification (stdlib)."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

EVIDENCE = Path('docs/animation/style_system/evidence.json')
MANIFEST = Path('blender/animation/showcase/animation_manifest.json')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def pointer_tokens(pointer):
    if not isinstance(pointer, str) or (pointer and not pointer.startswith('/')):
        raise ValueError('JSON pointer must be empty or begin with /')
    if re.search(r'~(?![01])', pointer):
        raise ValueError('JSON pointer contains an invalid ~ escape')
    return [part.replace('~1', '/').replace('~0', '~') for part in pointer[1:].split('/')] if pointer else []


def resolve_pointer(document, pointer):
    for token in pointer_tokens(pointer):
        if isinstance(document, list):
            if not re.fullmatch(r'0|[1-9][0-9]*', token):
                raise ValueError('JSON pointer requires a canonical array index')
            document = document[int(token)]
        elif isinstance(document, dict):
            document = document[token]
        else:
            raise ValueError('JSON pointer traverses a scalar')
    return document


def load_evidence(root):
    path = root / EVIDENCE
    if not path.is_file():
        raise ValueError(f'Missing evidence index: {path}; choose the repository with --root')
    data = json.loads(path.read_text(encoding='utf-8'))
    if data.get('schema_version') != 1 or not isinstance(data.get('routes'), dict):
        raise ValueError('Evidence index requires schema_version 1 and routes')
    if not isinstance(data.get('pack'), dict) or not isinstance(data.get('evidence'), list):
        raise ValueError('Evidence index requires pack and evidence records')
    ids = set()
    for row in data['evidence']:
        for key in ('id', 'group', 'topic', 'member', 'pointer', 'sha256', 'summary'):
            if key not in row or not isinstance(row[key], str):
                raise ValueError(f'Evidence record requires string {key}')
        if row['id'] in ids:
            raise ValueError(f'Duplicate evidence id: {row["id"]}')
        ids.add(row['id'])
        member = PurePosixPath(row['member'])
        if member.is_absolute() or '..' in member.parts or not member.parts:
            raise ValueError(f'Unsafe archive member: {row["member"]}')
        if not re.fullmatch('[0-9a-f]{64}', row['sha256']):
            raise ValueError(f'Invalid member SHA-256: {row["id"]}')
        pointer_tokens(row['pointer'])
    return data


def lookup(data, topic):
    topics = sorted(set(data['routes']) | {row['topic'] for row in data['evidence']})
    if topic is None:
        return {'topics': topics}
    selected = next((item for item in topics if item.casefold() == topic.casefold()), None)
    if selected is None:
        raise ValueError(f'Unknown topic {topic!r}; choose: {", ".join(topics)}')
    return {'topic': selected, 'routes': data['routes'].get(selected, []),
            'evidence': [row for row in data['evidence'] if row['topic'] == selected]}


def check(root, data):
    routes = set()
    for topic, paths in data['routes'].items():
        if not isinstance(paths, list):
            raise ValueError(f'Routes for {topic} must be a list')
        for route in paths:
            if not isinstance(route, str) or Path(route).is_absolute() or not (root / route).resolve().is_relative_to(root):
                raise ValueError(f'Route must remain inside repository root: {route!r}')
            if not (root / route).is_file():
                raise ValueError(f'Missing route file: {route}')
            routes.add(route)
    manifest = None
    if (root / MANIFEST).is_file():
        animations = json.loads((root / MANIFEST).read_text(encoding='utf-8')).get('animations', [])
        manifest = {'status_counts': dict(Counter(row.get('status', 'unknown') for row in animations)),
                    'research_only_count': sum(row.get('research_only') is True for row in animations)}
    return {'route_count': len(routes), 'evidence_count': len(data['evidence']), 'manifest': manifest}


def verify(root, data, override):
    pinned = data['pack']
    path = Path(override or pinned.get('path', '')).expanduser()
    if not path.is_absolute():
        path = root / path
    if not path.is_file():
        raise ValueError(f'Local archive unavailable: {path}; supply the matching file with --pack FILE')
    if path.stat().st_size != pinned.get('size'):
        raise ValueError('Archive size differs from pinned evidence; use the matching source with --pack FILE')
    if digest(path) != pinned.get('sha256'):
        raise ValueError('Archive SHA-256 differs from pinned evidence; use the matching source with --pack FILE')
    with zipfile.ZipFile(path) as archive:
        version = json.loads(archive.read('manifest.json'))['header']['version']
        if version != pinned.get('manifest_version'):
            raise ValueError(f'Archive manifest version differs: {version!r}')
        documents = {}
        for row in data['evidence']:
            member = row['member']
            if member not in documents:
                try:
                    raw = archive.read(member)
                except KeyError as error:
                    raise ValueError(f'Missing archive member: {member}') from error
                documents[member] = (hashlib.sha256(raw).hexdigest(), json.loads(raw))
            actual_hash, document = documents[member]
            if actual_hash != row['sha256']:
                raise ValueError(f'Member SHA-256 differs: {member} ({row["id"]})')
            try:
                resolve_pointer(document, row['pointer'])
            except (KeyError, IndexError, ValueError) as error:
                raise ValueError(f'Stale JSON pointer {row["id"]}: {member}#{row["pointer"]}: {error}') from error
    return {'evidence_verified': len(data['evidence']), 'members_verified': len(documents),
            'manifest_version': version, 'pack': str(path)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--json', action='store_true')
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('lookup', 'check', 'verify'):
        command = commands.add_parser(name)
        command.add_argument('--root', type=Path, default=argparse.SUPPRESS)
        command.add_argument('--json', action='store_true', default=argparse.SUPPRESS)
        if name == 'lookup':
            command.add_argument('topic', nargs='?')
        if name == 'verify':
            command.add_argument('--pack', help='Matching local archive; never downloaded or extracted')
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve()
        data = load_evidence(root)
        if args.command == 'lookup':
            result = lookup(data, args.topic)
        elif args.command == 'check':
            result = check(root, data)
        else:
            result = verify(root, data, args.pack)
        report = {'ok': True, 'command': args.command, **result}
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        report = {'ok': False, 'command': args.command, 'error': str(error)}
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif not report['ok']:
        print(f'animation knowledge: {report["error"]}', file=sys.stderr)
    elif args.command == 'lookup':
        print('Topics: ' + ', '.join(report['topics']) if 'topics' in report else 'Topic: ' + report['topic'])
        for route in report.get('routes', []):
            print(f'  Read: {route}')
        for row in report.get('evidence', []):
            print(f'  {row["id"]}: {row["summary"]}\n    {row["member"]}#{row["pointer"]}')
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
