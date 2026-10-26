"""Real local repositories exercise checkpoint/push preservation and cadence."""
import os
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from checkpoint_manager.core import (
        AutoSchedule, GitRepository, RepoConfig, RepoBlocked, RepoError,
        github_repository, redact,
    )
except ImportError:
    GitRepository = None


class CheckpointTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(GitRepository, 'Checkpoint manager is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo with spaces'
        self.repo.mkdir()
        self.git('init', '-q', '-b', 'study')
        self.git('config', 'user.name', 'Checkpoint Test')
        self.git('config', 'user.email', 'checkpoint@example.invalid')
        self.git('config', 'core.hooksPath', str(self.root / 'hooks'))
        self.git('config', 'commit.gpgsign', 'false')
        (self.root / 'hooks').mkdir()
        (self.repo / 'keep.txt').write_text('original\n')
        self.git('add', 'keep.txt')
        self.git('commit', '-qm', 'baseline')
        self.manager = GitRepository(RepoConfig('Test', self.repo, ''), stability_seconds=0)

    def git(self, *args, check=True):
        run = subprocess.run(['git', *args], cwd=self.repo, capture_output=True)
        if check:
            self.assertEqual(run.returncode, 0, run.stderr.decode(errors='replace'))
        return run.stdout.decode('utf-8', errors='replace').strip()

    def head(self):
        return self.git('rev-parse', 'HEAD')

    def test_commit_modified_new_and_deleted_files(self):
        before = self.head()
        (self.repo / 'keep.txt').unlink()
        (self.repo / 'new file [one].txt').write_text('new\n')
        result = self.manager.checkpoint()
        self.assertNotEqual(before, result.head)
        self.assertEqual(self.git('status', '--porcelain'), '')
        self.assertEqual(self.git('show', 'HEAD:new file [one].txt'), 'new')
        self.assertIn('keep.txt', self.git('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'))

    def test_no_change_does_not_create_commit(self):
        before = self.head()
        self.assertEqual(self.manager.checkpoint().head, before)

    def test_docs_commit_has_title_counts_lines_and_file_list(self):
        (self.repo / 'docs').mkdir()
        (self.repo / 'docs' / 'one.md').write_text('first\nsecond\n')
        (self.repo / 'docs' / 'two.md').write_text('third\n')
        self.manager.checkpoint()
        self.assertEqual(self.git('log', '-1', '--format=%s'), 'docs: change 2 docs files')
        body = self.git('log', '-1', '--format=%b')
        self.assertIn('Added: 2.', body)
        self.assertIn('Text lines: +3 / -0; binary files: 0.', body)
        self.assertIn('- Add: "docs/one.md"', body)
        self.assertIn('- Add: "docs/two.md"', body)
        self.assertIn('Repository: Test', body)

    def test_description_reports_modified_deleted_and_binary_paths(self):
        (self.repo / 'remove.txt').write_text('remove me\n')
        self.git('add', 'remove.txt')
        self.git('commit', '-qm', 'second baseline')
        (self.repo / 'remove.txt').unlink()
        (self.repo / 'keep.txt').write_text('replaced\nextra\n')
        (self.repo / 'asset.bin').write_bytes(b'\x00\x01\x02')
        self.manager.checkpoint()
        body = self.git('log', '-1', '--format=%b')
        self.assertIn('Added: 1. Modified: 1. Deleted: 1.', body)
        self.assertIn('Text lines: +2 / -2; binary files: 1.', body)
        self.assertIn('- Delete: "remove.txt"', body)
        self.assertIn('- Modify: "keep.txt"', body)
        self.assertIn('- Add: "asset.bin"', body)

    def test_lfs_pointer_lines_are_not_reported_as_asset_text(self):
        self.git('config', 'filter.lfs.clean', 'cat')
        self.git('config', 'filter.lfs.smudge', 'cat')
        self.git('config', 'filter.lfs.process', '')
        self.git('config', 'filter.lfs.required', 'false')
        (self.repo / '.gitattributes').write_text('*.blend filter=lfs diff=lfs merge=lfs -text\n')
        self.git('add', '.gitattributes')
        self.git('commit', '-qm', 'track fixture pointers')
        pointer = 'version https://git-lfs.github.com/spec/v1\noid sha256:' + 'a' * 64 + '\nsize 200000000\n'
        (self.repo / 'study.blend').write_text(pointer, newline='\n')
        self.manager.checkpoint()
        self.assertEqual(self.git('log', '-1', '--format=%s'), 'assets: change 1 asset file')
        body = self.git('log', '-1', '--format=%b')
        self.assertIn('Text lines: +0 / -0; binary files: 1.', body)

    def test_message_quotes_paths_and_keeps_unicode(self):
        name = 'notes [one] tiếng Việt.md'
        (self.repo / name).write_text('note\n', encoding='utf-8')
        self.manager.checkpoint()
        body = self.git('log', '-1', '--format=%b')
        self.assertIn('- Add: "notes [one] tiếng Việt.md"', body)

    def test_deleting_lfs_asset_and_tracking_rule_keeps_binary_stats(self):
        self.git('config', 'filter.lfs.clean', 'cat')
        self.git('config', 'filter.lfs.smudge', 'cat')
        self.git('config', 'filter.lfs.process', '')
        self.git('config', 'filter.lfs.required', 'false')
        (self.repo / '.gitattributes').write_text('*.blend filter=lfs diff=lfs merge=lfs -text\n')
        pointer = 'version https://git-lfs.github.com/spec/v1\noid sha256:' + 'b' * 64 + '\nsize 99999\n'
        (self.repo / 'study.blend').write_text(pointer, newline='\n')
        self.manager.checkpoint()
        (self.repo / 'study.blend').unlink()
        (self.repo / '.gitattributes').unlink()
        self.manager.checkpoint()
        body = self.git('log', '-1', '--format=%b')
        self.assertIn('Deleted: 2.', body)
        self.assertIn('Text lines: +0 / -1; binary files: 1.', body)

    def test_staged_work_is_preserved_and_not_committed(self):
        (self.repo / 'keep.txt').write_text('staged\n')
        self.git('add', 'keep.txt')
        (self.repo / 'keep.txt').write_text('unstaged\n')
        before, index = self.head(), self.git('diff', '--cached')
        with self.assertRaises(RepoBlocked):
            self.manager.checkpoint()
        self.assertEqual(self.head(), before)
        self.assertEqual(self.git('diff', '--cached'), index)
        self.assertEqual((self.repo / 'keep.txt').read_text(), 'unstaged\n')

    def test_intent_to_add_index_entry_is_preserved(self):
        (self.repo / 'planned.txt').write_text('user planned this addition')
        self.git('add', '-N', 'planned.txt')
        index_before = self.git('ls-files', '--stage')
        before = self.head()
        with self.assertRaises(RepoBlocked):
            self.manager.checkpoint()
        self.assertEqual(before, self.head())
        self.assertEqual(index_before, self.git('ls-files', '--stage'))

    def test_ignored_caches_backups_and_secrets_are_not_added(self):
        (self.repo / '.gitignore').write_text('ignored/\n')
        for name in ['ignored/a.txt', '__pycache__/a.pyc', 'asset.blend1', '.env', 'normal.txt']:
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('payload\n')
        snap = self.manager.scan()
        self.assertTrue(any(change.reason for change in snap.changes if change.path == '.env'))
        self.manager.checkpoint()
        tracked = self.git('ls-files').splitlines()
        self.assertIn('normal.txt', tracked)
        for name in ['ignored/a.txt', '__pycache__/a.pyc', 'asset.blend1', '.env']:
            self.assertNotIn(name, tracked)
            self.assertTrue((self.repo / name).exists())

    def test_lock_and_merge_state_block_without_touching_index(self):
        (self.repo / 'keep.txt').write_text('changed')
        for marker in ['index.lock', 'MERGE_HEAD']:
            with self.subTest(marker=marker):
                path = self.repo / '.git' / marker
                path.write_text(self.head())
                before = self.head()
                with self.assertRaises(RepoBlocked):
                    self.manager.checkpoint()
                self.assertEqual(self.head(), before)
                path.unlink()

    def test_detached_head_and_changed_branch_are_blocked(self):
        snap = self.manager.scan()
        self.git('checkout', '-qb', 'other')
        (self.repo / 'keep.txt').write_text('changed')
        with self.assertRaises(RepoBlocked):
            self.manager.checkpoint(expected_identity=snap.identity)
        self.git('checkout', '--detach', '-q')
        with self.assertRaises(RepoBlocked):
            self.manager.checkpoint()

    def test_failed_hook_keeps_staging_and_worktree(self):
        hook = self.root / 'hooks' / 'pre-commit'
        hook.write_text('#!/bin/sh\necho fixture-rejection >&2\nexit 1\n', newline='\n')
        hook.chmod(0o755)
        (self.repo / 'keep.txt').write_text('new')
        before = self.head()
        with self.assertRaisesRegex(RepoError, 'fixture-rejection'):
            self.manager.checkpoint()
        self.assertEqual(self.head(), before)
        self.assertIn('keep.txt', self.git('diff', '--cached', '--name-only'))
        self.assertEqual((self.repo / 'keep.txt').read_text(), 'new')

    def test_active_writer_is_skipped(self):
        (self.repo / 'keep.txt').write_text('a')
        original = self.manager.scan
        count = 0
        def changing_scan():
            nonlocal count
            count += 1
            if count == 2:
                (self.repo / 'keep.txt').write_text('modified while sampling')
            return original()
        before = self.head()
        with patch.object(self.manager, 'scan', side_effect=changing_scan):
            with self.assertRaises(RepoBlocked):
                self.manager.checkpoint()
        self.assertEqual(self.head(), before)
        self.assertEqual(self.git('diff', '--cached', '--name-only'), '')

    def test_ten_second_timer_is_not_a_quiet_period(self):
        schedule = AutoSchedule(interval=10, now=0)
        self.assertFalse(schedule.due(9.99))
        self.assertTrue(schedule.due(10))
        schedule.consume(10)
        self.assertFalse(schedule.due(19.99))
        self.assertTrue(schedule.due(20))
        self.assertEqual(AutoSchedule().interval, 10)

    def set_remote(self):
        remote = self.root / 'remote.git'
        run = subprocess.run(['git', 'init', '-q', '--bare', str(remote)], capture_output=True)
        self.assertEqual(run.returncode, 0)
        self.git('remote', 'add', 'origin', str(remote))
        self.git('push', '-qu', 'origin', 'study')
        self.manager = GitRepository(RepoConfig('Test', self.repo, str(remote)), stability_seconds=0)
        return remote

    def test_push_syncs_only_current_upstream(self):
        remote = self.set_remote()
        (self.repo / 'keep.txt').write_text('new')
        committed = self.manager.checkpoint().head
        report = self.manager.push()
        actual = subprocess.check_output(['git', '--git-dir', str(remote), 'rev-parse', 'refs/heads/study'], text=True).strip()
        self.assertEqual(actual, committed)
        self.assertIn(committed[:8], report)

    def test_non_fast_forward_rejection_does_not_force(self):
        remote = self.set_remote()
        other = self.root / 'other'
        subprocess.run(['git', 'clone', '-q', '-b', 'study', str(remote), str(other)], check=True, capture_output=True)
        for args in [('config', 'user.name', 'Other'), ('config', 'user.email', 'other@example.invalid'), ('config', 'core.hooksPath', str(self.root / 'hooks')), ('config', 'commit.gpgsign', 'false')]:
            subprocess.run(['git', '-C', str(other), *args], check=True, capture_output=True)
        (other / 'keep.txt').write_text('remote change')
        for args in [('add', 'keep.txt'), ('commit', '-qm', 'remote advance'), ('push', '-q')]:
            subprocess.run(['git', '-C', str(other), *args], check=True, capture_output=True)
        remote_head = subprocess.check_output(['git', '-C', str(other), 'rev-parse', 'HEAD'], text=True).strip()
        (self.repo / 'keep.txt').write_text('local change')
        before = self.manager.checkpoint().head
        with self.assertRaises(RepoError):
            self.manager.push()
        self.assertEqual(self.head(), before)
        actual = subprocess.check_output(['git', '--git-dir', str(remote), 'rev-parse', 'refs/heads/study'], text=True).strip()
        self.assertEqual(actual, remote_head)

    def test_push_does_not_publish_tags_from_followtags_config(self):
        remote = self.set_remote()
        (self.repo / 'keep.txt').write_text('new commit')
        self.manager.checkpoint()
        self.git('tag', '-a', 'private-review', '-m', 'keep local')
        self.git('config', 'push.followTags', 'true')
        self.manager.push()
        result = subprocess.run(['git', '--git-dir', str(remote), 'show-ref', '--verify', 'refs/tags/private-review'], capture_output=True)
        self.assertNotEqual(result.returncode, 0, 'Only the selected upstream branch may be pushed')

    def test_push_verifies_the_push_url_instead_of_fetch_url(self):
        fetch_remote = self.set_remote()
        push_remote = self.root / 'push-only.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(push_remote)], check=True, capture_output=True)
        self.git('config', 'remote.origin.pushurl', str(push_remote))
        manager = GitRepository(RepoConfig('Push only', self.repo, str(push_remote)), stability_seconds=0)
        (self.repo / 'keep.txt').write_text('new pushed version')
        head = manager.checkpoint().head
        self.assertIn(head[:8], manager.push())
        old_head = subprocess.check_output(['git', '--git-dir', str(fetch_remote), 'rev-parse', 'refs/heads/study'], text=True).strip()
        self.assertNotEqual(old_head, head)

    def test_wrong_remote_and_unverified_private_target_block_push(self):
        self.set_remote()
        wrong = GitRepository(RepoConfig('Wrong', self.repo, 'https://github.com/other/repo.git'), stability_seconds=0)
        with self.assertRaises(RepoBlocked):
            wrong.push()
        private = GitRepository(RepoConfig('Private', self.repo, self.manager.config.expected_remote, require_private=True), stability_seconds=0)
        with self.assertRaises(RepoBlocked):
            private.push()

    def test_rename_and_pathspec_characters_are_literal(self):
        (self.repo / 'keep.txt').rename(self.repo / 'literal [name].txt')
        self.manager.checkpoint()
        self.assertIn('literal [name].txt', self.git('ls-files'))

    def test_redaction_and_github_identity(self):
        self.assertEqual(github_repository('https://github.com/Tin0709/MD2-Research.git'), 'Tin0709/MD2-Research')
        self.assertEqual(github_repository('git@github.com:Tin0709/MD2-Research.git'), 'Tin0709/MD2-Research')
        self.assertNotIn('secretvalue', redact('https://user:secretvalue@github.com/a/b.git'))
        self.assertNotIn('ghp_' + 'A' * 36, redact('token ghp_' + 'A' * 36))

    def test_github_privacy_must_be_true_and_identity_must_match(self):
        url = 'https://github.com/Tin0709/MD2-Research.git'
        for payload, allowed in [
            ({'private': True, 'full_name': 'Tin0709/MD2-Research'}, True),
            ({'private': False, 'full_name': 'Tin0709/MD2-Research'}, False),
            ({'private': True, 'full_name': 'other/repo'}, False),
        ]:
            with self.subTest(payload=payload), patch.dict(os.environ, {'GH_TOKEN': 'fixture-only'}):
                with patch('urllib.request.OpenerDirector.open', return_value=io.BytesIO(json.dumps(payload).encode())):
                    if allowed:
                        self.manager.verify_private(url)
                    else:
                        with self.assertRaises(RepoBlocked):
                            self.manager.verify_private(url)

    def test_large_unfiltered_asset_is_blocked_before_staging(self):
        path = self.repo / 'large.bin'
        with path.open('wb') as stream:
            stream.truncate(101 * 1024 * 1024)
        before = self.head()
        with self.assertRaises(RepoBlocked):
            self.manager.checkpoint()
        self.assertEqual(before, self.head())
        self.assertEqual(self.git('diff', '--cached', '--name-only'), '')


if __name__ == '__main__':
    unittest.main()
