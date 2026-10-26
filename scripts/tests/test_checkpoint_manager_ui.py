"""Run the desktop controller against two disposable repositories."""
from pathlib import Path
import gc
import os
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
import unittest
import uuid
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from checkpoint_manager.core import GitRepository, RepoConfig
from checkpoint_manager.blender_bridge import BlenderBridge, BridgeConfig
try:
    from checkpoint_manager.desktop import CheckpointApp, SingleInstance
except ImportError:
    CheckpointApp = None


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(CheckpointApp, 'Desktop app is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.configs = []
        for name in ['One', 'Two']:
            path = self.base / name
            path.mkdir()
            for args in [('init', '-q', '-b', 'test'), ('config', 'user.name', 'UI Test'), ('config', 'user.email', 'ui@example.invalid'), ('config', 'commit.gpgsign', 'false'), ('config', 'core.hooksPath', str(self.base / 'no-hooks'))]:
                subprocess.run(['git', '-C', str(path), *args], check=True, capture_output=True)
            (path / 'work.txt').write_text('initial')
            for args in [('add', 'work.txt'), ('commit', '-qm', 'initial')]:
                subprocess.run(['git', '-C', str(path), *args], check=True, capture_output=True)
            self.configs.append(RepoConfig(name, path, ''))
        self.now = 0.0
        self.open_app()
        self.addCleanup(self.cleanup_root)
        self.wait_idle()

    def open_app(self, start_auto=False):
        try:
            self.root = tk.Tk()
        except tk.TclError as error:
            self.skipTest(str(error))
        self.root.withdraw()
        bridge = BlenderBridge(self.base / 'state', BridgeConfig(http_port=0, addon_port=0, timeout=.03))
        self.app = CheckpointApp(self.root, self.configs, self.base / 'state', clock=lambda: self.now, bridge=bridge, start_auto=start_auto)

    def cleanup_root(self):
        if not self.app.closed:
            self.app.pause_all()
            self.wait_idle()
            self.app.close()
        # The injected clock closes over this unittest case. Break that cycle
        # and collect destroyed Tk objects here on the main thread, rather than
        # letting a later Git worker trigger their Tcl destructors.
        self.app.clock = time.monotonic
        self.app = None
        self.root = None
        gc.collect()

    def wait_idle(self):
        deadline = time.monotonic() + 20
        while self.app.busy and time.monotonic() < deadline:
            self.root.update()
            time.sleep(0.01)
        self.root.update()
        self.assertFalse(self.app.busy, 'Desktop worker did not finish')

    def count(self, index):
        return int(subprocess.check_output(['git', '-C', str(self.configs[index].path), 'rev-list', '--count', 'HEAD']))

    def test_startup_and_passive_scan_never_commit(self):
        (self.configs[0].path / 'work.txt').write_text('pending')
        self.now = 10
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 1)
        self.assertTrue(all(not var.get() for var in self.app.auto_vars))
        self.assertEqual(self.app.uncommitted_vars[0].get(), 'Chưa commit: 1 file')

    def test_enabled_timer_commits_on_next_ten_second_tick(self):
        self.app.resume_all()
        (self.configs[0].path / 'work.txt').write_text('checkpoint')
        self.now = 9.99
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 1)
        self.now = 10
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 2)
        self.assertEqual(self.count(1), 1)
        self.app.pause_all()
        (self.configs[0].path / 'work.txt').write_text('after pause')
        self.now = 20
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 2)

    def test_explicit_auto_launch_waits_for_scan_then_uses_ten_second_timer(self):
        self.cleanup_root()
        self.open_app(start_auto=True)
        self.assertTrue(all(not value.get() for value in self.app.auto_vars))
        self.wait_idle()
        self.assertTrue(all(value.get() for value in self.app.auto_vars))
        (self.configs[0].path / 'work.txt').write_text('new automatic checkpoint')
        self.assertEqual(self.count(0), 1)
        self.now = 10
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 2)

    def test_pause_before_scan_cancels_explicit_auto_launch(self):
        self.cleanup_root()
        self.open_app(start_auto=True)
        self.app.pause_all()
        self.wait_idle()
        self.assertTrue(all(not value.get() for value in self.app.auto_vars))
        self.assertEqual(self.count(1), 1)
        self.app.pause_all()
        (self.configs[0].path / 'work.txt').write_text('after pause')
        self.now = 20
        self.app.tick()
        self.wait_idle()
        self.assertEqual(self.count(0), 1)

    def test_closing_stops_future_work(self):
        self.app.resume_all()
        self.app.close()
        self.assertTrue(all(not var.get() for var in self.app.auto_vars))
        self.assertFalse(self.app.busy)
        self.assertTrue(self.app.closed)

    def test_second_instance_is_blocked_until_first_releases(self):
        path = self.base / 'singleton.lock'
        first = SingleInstance(path)
        self.addCleanup(first.close)
        with self.assertRaises(RuntimeError):
            SingleInstance(path)
        first.close()
        second = SingleInstance(path)
        second.close()

    @unittest.skipUnless(os.name == 'nt', 'Windows named application mutex')
    def test_same_app_identity_blocks_different_state_directories(self):
        identity = 'Local\\CheckpointManagerTest_' + uuid.uuid4().hex
        first = SingleInstance(self.base / 'state-a' / 'lock', identity=identity)
        self.addCleanup(first.close)
        with self.assertRaises(RuntimeError):
            SingleInstance(self.base / 'state-b' / 'lock', identity=identity)
        first.close()
        second = SingleInstance(self.base / 'state-b' / 'lock', identity=identity)
        second.close()

    def test_pending_push_counts_two_local_commits_then_zero_after_push(self):
        config = self.configs[0]
        remote = self.base / 'counter-remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(remote)], check=True, capture_output=True)
        for args in [('remote', 'add', 'origin', str(remote)), ('push', '-qu', 'origin', 'test')]:
            subprocess.run(['git', '-C', str(config.path), *args], check=True, capture_output=True)
        for value in ['first local commit', 'second local commit']:
            (config.path / 'work.txt').write_text(value)
            for args in [('add', 'work.txt'), ('commit', '-qm', value)]:
                subprocess.run(['git', '-C', str(config.path), *args], check=True, capture_output=True)
        self.app.refresh()
        self.wait_idle()
        self.assertEqual(self.app.pending_push_vars[0].get(), 'Chưa push: 2 commit')
        self.assertEqual(self.app.uncommitted_vars[0].get(), 'Chưa commit: 0 file')
        subprocess.run(['git', '-C', str(config.path), 'push', '-q'], check=True, capture_output=True)
        self.app.refresh()
        self.wait_idle()
        self.assertEqual(self.app.pending_push_vars[0].get(), 'Chưa push: 0 commit')

    def test_push_click_pushes_immediately_without_confirmation(self):
        config = self.configs[0]
        remote = self.base / 'one-click-remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(remote)], check=True, capture_output=True)
        for args in [('remote', 'add', 'origin', str(remote)), ('push', '-qu', 'origin', 'test')]:
            subprocess.run(['git', '-C', str(config.path), *args], check=True, capture_output=True)
        (config.path / 'work.txt').write_text('ready to push')
        for args in [('add', 'work.txt'), ('commit', '-qm', 'local checkpoint')]:
            subprocess.run(['git', '-C', str(config.path), *args], check=True, capture_output=True)
        self.app.repositories[0] = GitRepository(RepoConfig(config.name, config.path, str(remote)))
        self.app.refresh()
        self.wait_idle()
        with patch('checkpoint_manager.desktop.messagebox.askyesno', side_effect=AssertionError('Push must not open a confirmation dialog')):
            self.app.push_now(0)
            self.wait_idle()
        actual = subprocess.check_output(['git', '--git-dir', str(remote), 'rev-parse', 'refs/heads/test'], text=True).strip()
        expected = subprocess.check_output(['git', '-C', str(config.path), 'rev-parse', 'HEAD'], text=True).strip()
        self.assertEqual(actual, expected)
        self.assertEqual(self.app.pending_push_vars[0].get(), 'Chưa push: 0 commit')

    def test_pause_while_busy_skips_the_next_repository(self):
        self.app.resume_all()
        for config in self.configs:
            (config.path / 'work.txt').write_text('new pending work')
        entered, release = threading.Event(), threading.Event()
        original = self.app.repositories[0].checkpoint
        def slow_checkpoint(*args, **kwargs):
            entered.set()
            release.wait(10)
            return original(*args, **kwargs)
        with patch.object(self.app.repositories[0], 'checkpoint', side_effect=slow_checkpoint):
            self.now = 10
            self.app.tick()
            self.assertTrue(entered.wait(5))
            # Refresh must not queue a second concurrent writer.
            self.app.refresh()
            self.app.pause_all()
            release.set()
            self.wait_idle()
        self.assertEqual(self.count(0), 2)
        self.assertEqual(self.count(1), 1, 'Pause must stop future repository transactions')

    def test_buttons_stay_visually_steady_during_scan(self):
        entered, release = threading.Event(), threading.Event()
        def slow_job():
            entered.set()
            release.wait(5)
            return []
        self.assertTrue(self.app._submit(slow_job))
        self.assertTrue(entered.wait(2))
        try:
            self.assertTrue(all(not button.instate(['disabled']) for button in self.app.action_buttons))
            self.assertFalse(self.app._submit(lambda: []), 'Clicks must still be serialized')
        finally:
            release.set()
            self.wait_idle()

    def test_blender_view_buttons_open_the_two_requested_views(self):
        def open_view(key):
            return {'animation': 1111, 'sabre': 2222}[key]
        with patch.object(self.app.view_launcher, 'open', side_effect=open_view):
            self.app.view_buttons['animation'].invoke()
            self.app.view_buttons['sabre'].invoke()
        log = self.app.log_widget.get('1.0', 'end')
        self.assertIn('Animation MD2 (PID 1111)', log)
        self.assertIn('Valorie + Sabre (PID 2222)', log)

    def test_copy_path_buttons_copy_each_blend_path_without_opening_blender(self):
        clipboard = {'text': ''}
        expected = {
            'animation': Path.home() / 'Desktop/MD2 Research/blender/MD2_Animation_Library_BrowserFixed.blend',
            'sabre': Path.home() / 'Desktop/MD2 Research/blender/prototype_sabre/MD2_Valorie_Sabre_Source_Showcase.blend',
        }
        def append(text):
            clipboard['text'] += text
        # Do not overwrite the user's actual Windows clipboard during tests.
        with patch.object(self.root, 'clipboard_clear', side_effect=lambda: clipboard.update(text='')):
            with patch.object(self.root, 'clipboard_append', side_effect=append):
                with patch.object(self.app.view_launcher, 'open', side_effect=AssertionError('Copy must not launch Blender')):
                    for key, path in expected.items():
                        self.app.view_copy_buttons[key].invoke()
                        self.assertEqual(clipboard['text'], str(path))

    def test_close_while_busy_cannot_be_resumed(self):
        self.app.resume_all()
        for config in self.configs:
            (config.path / 'work.txt').write_text('new work')
        entered, release = threading.Event(), threading.Event()
        original = self.app.repositories[0].checkpoint
        def slow_checkpoint(*args, **kwargs):
            entered.set()
            release.wait(10)
            return original(*args, **kwargs)
        with patch.object(self.app.repositories[0], 'checkpoint', side_effect=slow_checkpoint):
            self.now = 10
            self.app.tick()
            self.assertTrue(entered.wait(5))
            self.app.close()
            self.app.resume_all()
            self.app.auto_vars[1].set(True)
            self.app.toggle_auto(1)
            release.set()
            self.wait_idle()
        self.assertTrue(self.app.closed)
        self.assertEqual(self.count(0), 2)
        self.assertEqual(self.count(1), 1)


if __name__ == '__main__':
    unittest.main()
