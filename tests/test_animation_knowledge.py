"""Real-file fixtures for the read-only animation knowledge CLI."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/animation_knowledge.py'


class KnowledgeCliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.evidence_path = self.root / 'docs/animation/style_system/evidence.json'
        self.evidence_path.parent.mkdir(parents=True)
        (self.evidence_path.parent / 'README.md').write_text('Fixture guide\n')
        self.pack = self.root / 'local.mcpack'
        self.member = b'{"a/b":{"~key":[{"value":7}]}}'
        with zipfile.ZipFile(self.pack, 'w') as archive:
            archive.writestr('manifest.json', '{"header":{"version":"1.1.60"}}')
            archive.writestr('entity/player.json', self.member)
        self.data = {
            'schema_version': 1,
            'pack': {'path': str(self.pack), 'sha256': self.digest(self.pack),
                     'size': self.pack.stat().st_size, 'manifest_version': '1.1.60'},
            'evidence': [{'id': 'P01', 'group': 'player', 'topic': 'walk',
                          'member': 'entity/player.json', 'pointer': '/a~1b/~0key/0/value',
                          'sha256': hashlib.sha256(self.member).hexdigest(),
                          'summary': 'Fixture supported value.'}],
            'routes': {'walk': ['docs/animation/style_system/README.md']},
        }
        self.save()

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def save(self):
        self.evidence_path.write_text(json.dumps(self.data))

    def cli(self, *arguments, ok=True):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--root', str(self.root), '--json', *arguments],
            capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        payload = json.loads(result.stdout or result.stderr)
        self.assertEqual(payload['ok'], ok)
        return payload

    def test_lookup_lists_topics_and_routes_with_source_evidence(self):
        self.assertEqual(self.cli('lookup')['topics'], ['walk'])
        report = self.cli('lookup', 'WALK')
        self.assertEqual(report['routes'], ['docs/animation/style_system/README.md'])
        self.assertEqual(report['evidence'][0]['id'], 'P01')
        self.assertEqual(report['evidence'][0]['pointer'], '/a~1b/~0key/0/value')

    def test_unknown_topic_fails_actionably(self):
        self.assertIn('walk', self.cli('lookup', 'missing', ok=False)['error'])

    def test_check_requires_no_pack_and_counts_live_manifest_if_present(self):
        self.pack.unlink()
        report = self.cli('check')
        self.assertEqual(report['route_count'], 1)
        self.assertEqual(report['evidence_count'], 1)
        self.assertIsNone(report['manifest'])
        manifest = self.root / 'blender/animation/showcase/animation_manifest.json'
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({'animations': [
            {'status': 'approved', 'research_only': True}, {'status': 'pending'}]}))
        report = self.cli('check')['manifest']
        self.assertEqual(report['status_counts'], {'approved': 1, 'pending': 1})
        self.assertEqual(report['research_only_count'], 1)

    def test_check_rejects_missing_route(self):
        self.data['routes']['walk'] = ['missing.md']
        self.save()
        self.assertIn('missing.md', self.cli('check', ok=False)['error'])

    def test_check_rejects_routes_outside_root_including_symlinks(self):
        outside = Path(tempfile.gettempdir()) / 'gaf-animation-route-outside'
        for route in ['../gaf-animation-route-outside', str(outside)]:
            self.data['routes']['walk'] = [route]
            self.save()
            self.assertIn('inside', self.cli('check', ok=False)['error'])
        (self.root / 'escape').symlink_to(Path(tempfile.gettempdir()))
        self.data['routes']['walk'] = ['escape']
        self.save()
        self.assertIn('inside', self.cli('check', ok=False)['error'])

    def test_verify_checks_archive_members_and_escaped_rfc6901_pointer(self):
        report = self.cli('verify')
        self.assertEqual(report['evidence_verified'], 1)
        self.assertEqual(report['manifest_version'], '1.1.60')
        result = subprocess.run([sys.executable, str(SCRIPT), 'verify', '--root',
                                 str(self.root), '--pack', str(self.pack), '--json'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(json.loads(result.stdout)['ok'])

    def test_verify_missing_archive_explains_pack_override(self):
        self.pack.unlink()
        self.assertIn('--pack', self.cli('verify', ok=False)['error'])

    def test_verify_rejects_archive_hash_and_size_mismatch(self):
        self.data['pack']['sha256'] = '0' * 64
        self.save()
        self.assertIn('SHA-256', self.cli('verify', ok=False)['error'])
        self.data['pack']['sha256'] = self.digest(self.pack)
        self.data['pack']['size'] += 1
        self.save()
        self.assertIn('size', self.cli('verify', ok=False)['error'])

    def test_verify_rejects_member_hash_mismatch(self):
        self.data['evidence'][0]['sha256'] = '0' * 64
        self.save()
        self.assertIn('entity/player.json', self.cli('verify', ok=False)['error'])

    def test_verify_rejects_stale_pointer_and_invalid_array_index(self):
        for pointer in ['/a~1b/~0key/0/missing', '/a~1b/~0key/01', '/a~1b/~0key/-1']:
            self.data['evidence'][0]['pointer'] = pointer
            self.save()
            self.assertIn('pointer', self.cli('verify', ok=False)['error'].lower())

    def test_verify_rejects_manifest_version_mismatch(self):
        self.data['pack']['manifest_version'] = '1.1.61'
        self.save()
        self.assertIn('version', self.cli('verify', ok=False)['error'])

    def test_check_rejects_duplicate_ids_and_bad_pointer_escape(self):
        self.data['evidence'].append(dict(self.data['evidence'][0]))
        self.save()
        self.assertIn('duplicate', self.cli('check', ok=False)['error'].lower())
        self.data['evidence'].pop()
        self.data['evidence'][0]['pointer'] = '/bad~2escape'
        self.save()
        self.assertIn('pointer', self.cli('check', ok=False)['error'].lower())

    def test_all_commands_leave_fixture_files_and_mtimes_unchanged(self):
        def snapshot():
            return {str(p.relative_to(self.root)): (self.digest(p), p.stat().st_mtime_ns)
                    for p in self.root.rglob('*') if p.is_file()}
        before = snapshot()
        for command in ['lookup', 'check', 'verify']:
            self.cli(command)
        self.assertEqual(snapshot(), before)


if __name__ == '__main__':
    unittest.main()
