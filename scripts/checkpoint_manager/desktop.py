"""A visible desktop UI. Opening the app never enables Git writes."""
from datetime import datetime
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import queue
import threading
import time
import tkinter as tk
from .ui_widgets import InAppDialog, Notifications
from .layout import build_layout

from .core import AutoSchedule, FilesChanging, GitRepository, RepoBlocked, RepoConfig, redact
from .blender_bridge import BlenderBridge, BridgeMonitor
from .blender_views import BlenderViewLauncher, VIEW_LABELS


class SingleInstance:
    """An OS-released file lock, never a stale PID-file-only guard."""
    def __init__(self, path, identity=None):
        self._mutex = None
        self._kernel = None
        self.file = None
        if os.name == 'nt' and identity:
            import ctypes
            from ctypes import wintypes
            self._kernel = ctypes.WinDLL('kernel32', use_last_error=True)
            self._kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
            self._kernel.CreateMutexW.restype = wintypes.HANDLE
            self._kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            self._kernel.ReleaseMutex.argtypes = [wintypes.HANDLE]
            ctypes.set_last_error(0)
            handle = self._kernel.CreateMutexW(None, True, identity)
            error = ctypes.get_last_error()
            if not handle:
                raise RuntimeError('Không thể tạo khóa ứng dụng Windows.')
            if error == 183:
                self._kernel.CloseHandle(handle)
                raise RuntimeError('Git Checkpoint Manager đang mở. Hãy dùng cửa sổ hiện tại.')
            self._mutex = handle
        try:
            self._lock_file(path)
        except Exception:
            self.close()
            raise

    def _lock_file(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file = path.open('a+b')
        if path.stat().st_size == 0:
            self.file.write(b'0')
            self.file.flush()
        self.file.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file.close()
            raise RuntimeError('Git Checkpoint Manager đang mở. Hãy dùng cửa sổ hiện tại.') from None

    def close(self):
        if self.file is not None and not self.file.closed:
            self.file.close()
        if self._mutex is not None:
            self._kernel.ReleaseMutex(self._mutex)
            self._kernel.CloseHandle(self._mutex)
            self._mutex = None


class CheckpointApp:
    def __init__(self, root, configs, state_dir, clock=time.monotonic, bridge=None, start_auto=False):
        self.root, self.configs, self.clock = root, tuple(configs), clock
        self.state_dir = Path(state_dir)
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.logger = logging.Logger('checkpoint-desktop')
        handler = RotatingFileHandler(self.state_dir / 'manager.log', maxBytes=1_000_000, backupCount=2, encoding='utf-8')
        self.logger.addHandler(handler)
        try:
            settings = json.loads((self.state_dir / 'settings.json').read_text(encoding='utf-8'))
            interval = min(3600, max(10, int(settings.get('interval_seconds', 10))))
        except (OSError, ValueError, TypeError, AttributeError):
            interval = 10
        self.schedule = AutoSchedule(interval, now=clock())
        self.repositories = [GitRepository(config) for config in self.configs]
        self.snapshots = [None] * len(configs)
        self.last_checkpoint = ['—'] * len(configs)
        self.auto_vars = [tk.BooleanVar(root, False) for _ in configs]
        self.auto_permits = [threading.Event() for _ in configs]
        self.repo_text = [tk.StringVar(root, 'Đang đọc trạng thái…') for _ in configs]
        self.pending_push_vars = [tk.StringVar(root, 'Chưa push: —') for _ in configs]
        self.uncommitted_vars = [tk.StringVar(root, 'Chưa commit: —') for _ in configs]
        self.remote_extra_vars = [tk.StringVar(root, 'GitHub có thêm: —') for _ in configs]
        self.pending_push_labels = []
        self.uncommitted_labels = []
        self.repo_sections = []
        self.branch_vars = [tk.StringVar(root, '—') for _ in configs]
        self.head_detail_vars = [tk.StringVar(root, '—') for _ in configs]
        self.upstream_detail_vars = [tk.StringVar(root, '—') for _ in configs]
        self.checkpoint_detail_vars = [tk.StringVar(root, '—') for _ in configs]
        self.counts_detail_vars = [tk.StringVar(root, 'Đang đọc…') for _ in configs]
        self.notifications = Notifications(root)
        self.dialog = InAppDialog(root)
        self.last_issue_messages = [''] * len(configs)
        self.interval_var = tk.StringVar(root, str(interval))
        self.mode_var = tk.StringVar(root, 'ĐÃ TẠM DỪNG • Kiểm tra thay đổi trước khi bật tự commit')
        self.countdown_var = tk.StringVar(root, f'Chu kỳ quét: {interval}s • Chỉ commit khi bạn bật Tự commit')
        self.busy, self.closed, self.closing = False, False, False
        self.auto_start_pending = start_auto
        self.events = queue.Queue()
        self.after_ids = {}
        self.action_buttons = []
        self.repo_lights = []
        self.repo_issues = [False] * len(configs)
        self.busy_indices = ()
        self.bridge_detail = tk.StringVar(root, 'Đang kiểm tra server và Blender…')
        research = next((config.path for config in configs if config.name == 'MD2 Research'), None)
        self.view_launcher = BlenderViewLauncher(self.state_dir, research)
        self.view_buttons = {}
        self.view_copy_buttons = {}
        self._build()
        self.bridge_monitor = BridgeMonitor(bridge or BlenderBridge(self.state_dir))
        root.protocol('WM_DELETE_WINDOW', self.close)
        self.log('App đã mở ở trạng thái tạm dừng. Bật tự commit khi bạn đã sẵn sàng; Push luôn thủ công.')
        self.log('Tạm dừng tất cả trước khi session khác hoặc bạn tự chạy lệnh Git. App không khóa các công cụ Git khác.')
        self.refresh()
        self.after_ids['poll'] = root.after(100, self._poll)
        self.after_ids['heartbeat'] = root.after(1000, self._heartbeat)

    def _build(self):
        build_layout(self)

    def log(self, message):
        message = redact(message)
        line = datetime.now().strftime('%H:%M:%S') + '  ' + message
        self.logger.info(line)
        self.log_widget.configure(state='normal')
        self.log_widget.insert('end', line + '\n')
        # Bound memory as well as the rotated disk log.
        if int(self.log_widget.index('end-1c').split('.')[0]) > 600:
            self.log_widget.delete('1.0', '101.0')
        self.log_widget.see('end')
        self.log_widget.configure(state='disabled')

    def _submit(self, job, kind='result', indices=None, label='Đang quét'):
        if self.busy or self.closed or self.closing:
            return False
        self.busy = True
        self.busy_indices = tuple(range(len(self.configs))) if indices is None else tuple(indices)
        self.activity_light.set('working')
        for index in self.busy_indices:
            self.repo_lights[index].set('working', label)
        def run():
            try:
                self.events.put((kind, job()))
            except Exception as error:
                self.events.put(('error', redact(str(error))))
        threading.Thread(target=run, name='checkpoint-git-worker', daemon=True).start()
        return True

    def _cycle(self, indices, auto_flags, anchors, permits=None):
        rows = []
        for index in indices:
            repository = self.repositories[index]
            try:
                before = repository.scan()
                allowed = auto_flags[index] and (permits is None or permits[index].is_set())
                after = repository.checkpoint(expected_identity=anchors[index]) if allowed else before
                changed = after.head != before.head
                rows.append((index, after, f'Checkpoint {after.head[:8]}' if changed else '', False, changed))
            except FilesChanging as error:
                rows.append((index, None, str(error), False, False))
            except Exception as error:
                rows.append((index, None, redact(str(error)), True, False))
        return rows

    def _anchors(self):
        return [snapshot.identity if snapshot else None for snapshot in self.snapshots]

    def refresh(self):
        self._submit(lambda: self._cycle(range(len(self.configs)), [False] * len(self.configs), self._anchors()))

    def tick(self):
        if self.closed or self.closing:
            return
        remaining = max(0, self.schedule.last + self.schedule.interval - self.clock())
        self.countdown_var.set(('Đang thực hiện thao tác Git…' if self.busy else f'Lượt quét tiếp theo: {remaining:.0f}s') + ' • Số commit dựa trên lần đồng bộ GitHub gần nhất')
        if self.schedule.due(self.clock()) and not self.busy:
            flags = [variable.get() for variable in self.auto_vars]
            anchors = self._anchors()
            self._submit(lambda: self._cycle(range(len(self.configs)), flags, anchors, self.auto_permits))
            self.schedule.consume(self.clock())

    def _heartbeat(self):
        if not self.closed:
            self.tick()
            self.after_ids['heartbeat'] = self.root.after(1000, self._heartbeat)

    def _poll(self):
        if self.closed:
            return
        self._poll_blender()
        try:
            kind, value = self.events.get_nowait()
        except queue.Empty:
            pass
        else:
            self.busy = False
            if kind == 'error':
                for index in self.busy_indices:
                    self.repo_issues[index] = True
                self.pause_all()
                self.log('LỖI: ' + value)
                self.notifications.show('Cần kiểm tra', value, kind='error')
            elif kind == 'details':
                title, text = value
                self.dialog.show_details(title, text)
            else:
                for index, snapshot, message, disable, committed in value:
                    if disable:
                        self.repo_issues[index] = True
                        self.auto_vars[index].set(False)
                        self.auto_permits[index].clear()
                        self.repo_text[index].set('Cần kiểm tra: ' + message[:400])
                        if message != self.last_issue_messages[index]:
                            self.repo_sections[index].set_expanded(True)
                            self.notifications.show(self.configs[index].name, message, kind='error')
                            self.last_issue_messages[index] = message
                    if snapshot:
                        self.repo_issues[index] = snapshot.staged
                        self.snapshots[index] = snapshot
                        if committed:
                            self.last_checkpoint[index] = datetime.now().strftime('%H:%M:%S')
                        excluded = len(snapshot.changes) - len(snapshot.eligible)
                        counts = snapshot.ahead_behind.split()
                        known = len(counts) == 2 and all(value.isdecimal() for value in counts)
                        self.uncommitted_vars[index].set(f'Chưa commit: {len(snapshot.changes)} file')
                        self.pending_push_vars[index].set(f'Chưa push: {counts[0]} commit' if known else 'Chưa push: chưa xác định')
                        self.remote_extra_vars[index].set(f'GitHub có thêm: {counts[1]} commit' if known else 'GitHub: chưa có dữ liệu so sánh')
                        self.pending_push_labels[index].set_kind('warn' if known and int(counts[0]) else 'success' if known else 'neutral')
                        self.uncommitted_labels[index].set_kind('warn' if snapshot.changes else 'success')
                        self.branch_vars[index].set(snapshot.branch or 'DETACHED')
                        self.head_detail_vars[index].set(snapshot.head[:8])
                        self.upstream_detail_vars[index].set(snapshot.upstream or 'chưa có')
                        self.checkpoint_detail_vars[index].set(self.last_checkpoint[index])
                        self.counts_detail_vars[index].set(f'Hợp lệ: {len(snapshot.eligible)} file   |   Bỏ qua: {excluded}   |   Đã stage: {"có" if snapshot.staged else "không"}')
                        self.repo_text[index].set('File đã stage được giữ nguyên; tạm dừng tự commit để bạn kiểm tra.' if snapshot.staged else '')
                        self.last_issue_messages[index] = ''
                    if message:
                        self.log(f'{self.configs[index].name}: {message}')
                        if not disable and kind in {'manual_commit', 'push_result'}:
                            self.notifications.show(self.configs[index].name, message)
            self._update_mode()
            if kind == 'result' and self.auto_start_pending and not self.closing:
                self.auto_start_pending = False
                self.resume_all()
            if self.closing:
                self._destroy()
                return
        self.after_ids['poll'] = self.root.after(100, self._poll)

    def apply_interval(self):
        try:
            seconds = int(self.interval_var.get())
            if not 10 <= seconds <= 3600:
                raise ValueError
        except ValueError:
            self.notifications.show('Khoảng quét không hợp lệ', 'Chọn số giây từ 10 đến 3600.', kind='error')
            return
        path = self.state_dir / 'settings.json'
        temporary = path.with_suffix('.tmp')
        try:
            temporary.write_text(json.dumps({'interval_seconds': seconds}), encoding='utf-8')
            temporary.replace(path)
        except OSError as error:
            self.notifications.show('Không lưu được khoảng quét', redact(str(error)), kind='error')
            return
        self.schedule.interval = seconds
        self.schedule.consume(self.clock())
        self.log(f'Đã đặt khoảng quét: {seconds} giây. Không có thời gian chờ 60 giây.')
        self.notifications.show('Đã cập nhật', f'Quét mỗi {seconds} giây khi app đang mở.')

    def _update_mode(self):
        count = sum(variable.get() for variable in self.auto_vars)
        self.mode_var.set(f'TỰ COMMIT ĐANG BẬT: {count}/{len(self.configs)} REPO • Push vẫn thủ công' if count else 'ĐÃ TẠM DỪNG • Chỉ quét, không tự commit')
        self.mode_badge.set_kind('success' if count else 'neutral')
        if not self.busy:
            self.activity_light.set('error' if any(self.repo_issues) else 'ok' if count else 'idle')
            for index, variable in enumerate(self.auto_vars):
                if self.repo_issues[index]:
                    self.repo_lights[index].set('error', 'Cần kiểm tra')
                elif variable.get():
                    self.repo_lights[index].set('ok', 'Tự commit bật')
                else:
                    self.repo_lights[index].set('idle', 'Tạm dừng')

    def toggle_auto(self, index):
        if self.closed or self.closing:
            self.auto_vars[index].set(False)
            self.auto_permits[index].clear()
            return
        if self.auto_vars[index].get() and self.snapshots[index] is None:
            self.auto_vars[index].set(False)
            self.log(f'{self.configs[index].name}: đợi đọc trạng thái thành công trước khi bật.')
        if self.auto_vars[index].get():
            self.auto_permits[index].set()
        else:
            self.auto_permits[index].clear()
        self.schedule.consume(self.clock())
        self._update_mode()

    def resume_all(self):
        if self.closed or self.closing:
            return
        for index, variable in enumerate(self.auto_vars):
            variable.set(self.snapshots[index] is not None)
            if variable.get():
                self.auto_permits[index].set()
        self.schedule.consume(self.clock())
        self._update_mode()
        enabled = [config.name for config, variable in zip(self.configs, self.auto_vars) if variable.get()]
        self.log(f'Đã bật tự commit cho {len(enabled)}/{len(self.configs)} repo ({", ".join(enabled) or "chưa có"}). Quét mỗi {self.schedule.interval} giây.')

    def pause_all(self):
        self.auto_start_pending = False
        for index, variable in enumerate(self.auto_vars):
            variable.set(False)
            self.auto_permits[index].clear()
        self._update_mode()
        self.log('Đã tạm dừng tự commit. Thao tác đang stage/commit/push sẽ hoàn tất trước khi dừng.')

    def show_changes(self, index):
        def job():
            return self.configs[index].name, self.repositories[index].details()
        self._submit(job, kind='details', indices=[index], label='Đang đọc thay đổi')

    def commit_now(self, index):
        snapshot = self.snapshots[index]
        if not snapshot or self.busy or self.closed or self.closing or self.dialog.active:
            return
        identity = snapshot.identity
        def confirm():
            if self.busy:
                self.notifications.show('Đang xử lý Git', 'Đợi thao tác hiện tại hoàn tất rồi bấm Commit ngay.')
                return False
            flags = [False] * len(self.configs)
            flags[index] = True
            anchors = self._anchors()
            anchors[index] = identity
            return self._submit(lambda: self._cycle([index], flags, anchors), kind='manual_commit', indices=[index], label='Đang commit')
        self.dialog.show_confirm('Commit ngay · ' + self.configs[index].name,
            f'Commit các thay đổi hợp lệ trên nhánh {snapshot.branch}?\n\nFile staged sẵn được giữ nguyên. Thao tác này chỉ tạo commit cục bộ.', confirm)

    def push_now(self, index):
        snapshot = self.snapshots[index]
        if not snapshot or self.busy or self.dialog.active:
            return
        identity = snapshot.identity
        def job():
            message = self.repositories[index].push(expected_identity=identity)
            return [(index, self.repositories[index].scan(), message, False, False)]
        self.log(f'{self.configs[index].name}: đang Push theo yêu cầu của bạn…')
        self._submit(job, kind='push_result', indices=[index], label='Đang Push')

    def start_blender(self):
        if not self.closed and not self.closing:
            self.blender_light.set('working', 'Đang xử lý yêu cầu…')
            self.bridge_monitor.request_start()

    def open_blender_view(self, key):
        if self.closed or self.closing:
            return
        label = VIEW_LABELS.get(key, 'Blender')
        try:
            pid = self.view_launcher.open(key)
            self.log(f'Đã mở {label} (PID {pid}).')
        except (OSError, ValueError) as error:
            self.log(f'Không mở được {label}: {error}')
            self.notifications.show('Không mở được ' + label, redact(str(error)), kind='error')

    def copy_blender_view_path(self, key):
        if self.closed or self.closing:
            return
        label = VIEW_LABELS.get(key, 'Blender')
        try:
            path = self.view_launcher.blend_path(key)
            self.root.clipboard_clear()
            self.root.clipboard_append(str(path))
            self.root.update_idletasks()
            self.log(f'Đã copy path {label}.')
            self.notifications.show('Đã copy đường dẫn', str(path))
        except (OSError, ValueError, tk.TclError) as error:
            self.log(f'Không copy được path {label}: {error}')
            self.notifications.show('Không copy được đường dẫn', redact(str(error)), kind='error')

    def refresh_blender(self):
        if not self.closed and not self.closing:
            self.bridge_monitor.refresh()

    def _poll_blender(self):
        while True:
            try:
                kind, value = self.bridge_monitor.events.get_nowait()
            except queue.Empty:
                return
            if kind == 'message':
                self.log('Blender MCP: ' + value)
            else:
                color = 'ok' if value.connected else 'working' if value.server_ready or value.blender_ready else 'idle'
                self.blender_light.set(color, value.label)
                stamp = datetime.now().strftime('%H:%M:%S')
                self.bridge_detail.set(f'{value.detail}  •  Cập nhật {stamp}')

    def close(self):
        if self.closed:
            return
        self.pause_all()
        self.closing = True
        self.bridge_monitor.close()
        if self.busy:
            self.mode_var.set('ĐANG ĐÓNG • Đợi thao tác Git hiện tại hoàn tất; không chạy lượt mới')
        else:
            self._destroy()

    def _destroy(self):
        self.closed = True
        self.dialog.close()
        self.notifications.close()
        for timer in self.after_ids.values():
            try:
                self.root.after_cancel(timer)
            except tk.TclError:
                pass
        for handler in self.logger.handlers:
            handler.close()
        self.root.destroy()


def main(auto_commit=False):
    if os.name == 'nt':
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('Tin0709.GAFGitCheckpointManager')
    root = tk.Tk()
    root.withdraw()
    state_dir = Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.local' / 'state'))) / 'GAFGitCheckpointManager'
    try:
        instance = SingleInstance(state_dir / 'manager.lock', identity='Local\\Tin0709.GAFGitCheckpointManager')
    except RuntimeError:
        # Reuse the existing application instead of opening a native dialog.
        if os.name == 'nt':
            import ctypes
            user32 = ctypes.windll.user32
            user32.FindWindowW.restype = ctypes.c_void_p
            user32.FindWindowW.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p]
            user32.ShowWindow.argtypes = [ctypes.c_void_p, ctypes.c_int]
            user32.SetForegroundWindow.argtypes = [ctypes.c_void_p]
            window = user32.FindWindowW(None, 'Git Checkpoint Manager — GameAssetFactory & MD2')
            if window:
                user32.ShowWindow(window, 9)
                user32.SetForegroundWindow(window)
        root.destroy()
        return
    repository = Path(__file__).resolve().parents[2]
    desktop = Path.home() / 'Desktop'
    configs = [
        RepoConfig('GameAssetFactory', repository, 'https://github.com/Tin0709/GameAssetFactory.git'),
        RepoConfig('MD2 Research', desktop / 'MD2 Research', 'https://github.com/Tin0709/MD2-Research.git', require_private=True),
    ]
    try:
        CheckpointApp(root, configs, state_dir, start_auto=auto_commit)
        root.deiconify()
        root.mainloop()
    finally:
        instance.close()


if __name__ == '__main__':
    main()
