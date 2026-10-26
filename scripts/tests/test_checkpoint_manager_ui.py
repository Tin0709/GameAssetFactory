"""Run the desktop controller against two disposable repositories."""
from pathlib import Path
import gc
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from checkpoint_manager.core import RepoConfig
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
        try:
            self.root = tk.Tk()
        except tk.TclError as error:
            self.skipTest(str(error))
        self.root.withdraw()
        self.now = 0.0
        bridge = BlenderBridge(self.base / 'state', BridgeConfig(http_port=0, addon_port=0, timeout=.03))
        self.app = CheckpointApp(self.root, self.configs, self.base / 'state', clock=lambda: self.now, bridge=bridge)
        self.addCleanup(self.cleanup_root)
        self.wait_idle()

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
        self.assertIn('1', self.app.repo_text[0].get())

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
