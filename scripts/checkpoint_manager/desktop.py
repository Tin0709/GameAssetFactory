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
from tkinter import messagebox, scrolledtext, ttk

from .core import AutoSchedule, FilesChanging, GitRepository, RepoBlocked, RepoConfig, redact
from .blender_bridge import BlenderBridge, BridgeMonitor
from .blender_views import BlenderViewLauncher, VIEW_LABELS


class StatusLight(ttk.Frame):
    COLORS = {'idle': '#64748b', 'working': '#fbbf24', 'ok': '#34d399', 'error': '#fb7185'}

    def __init__(self, parent, panel=False):
        background = '#182337' if panel else '#0b1120'
        super().__init__(parent, style='Panel.TFrame' if panel else 'TFrame')
        self.canvas = tk.Canvas(self, width=13, height=13, background=background, highlightthickness=0, borderwidth=0)
        self.canvas.pack(side='left', padx=(0, 5))
        self.dot = self.canvas.create_oval(3, 3, 11, 11, fill=self.COLORS['idle'], outline='')
        self.label = ttk.Label(self, style='Panel.TLabel' if panel else 'Muted.TLabel')
        self.label.pack(side='left')
        self.state = 'idle'
        self.text = ''

    def set(self, state, text=''):
        if state != self.state:
            self.canvas.itemconfigure(self.dot, fill=self.COLORS[state])
            self.state = state
        if text != self.text:
            self.label.configure(text=text)
            self.text = text


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
        root = self.root
        root.title('Git Checkpoint Manager — GameAssetFactory & MD2')
        root.geometry('1120x940')
        root.minsize(980, 860)
        root.configure(background='#0b1120')
        style = ttk.Style(root)
        style.theme_use('clam')
        style.configure('.', font=('Segoe UI', 10))
        style.configure('TFrame', background='#0b1120')
        style.configure('Panel.TFrame', background='#182337')
        style.configure('TLabel', background='#0b1120', foreground='#e2e8f0')
        style.configure('Panel.TLabel', background='#182337', foreground='#cbd5e1')
        style.configure('Title.TLabel', font=('Segoe UI', 21, 'bold'), foreground='#f8fafc')
        style.configure('Repo.TLabel', background='#182337', foreground='#f8fafc', font=('Segoe UI', 13, 'bold'))
        style.configure('Metric.TLabel', background='#182337', foreground='#e2e8f0', font=('Segoe UI', 11, 'bold'))
        style.configure('Muted.TLabel', foreground='#94a3b8')
        style.configure('Status.TLabel', foreground='#34d399', font=('Segoe UI', 10, 'bold'))
        style.configure('TButton', padding=(12, 7), background='#2a3b55', foreground='#f8fafc', borderwidth=0)
        style.map('TButton', background=[('active', '#3b5273'), ('disabled', '#1e293b')], foreground=[('disabled', '#64748b')])
        style.configure('Accent.TButton', background='#087f71')
        style.map('Accent.TButton', background=[('active', '#0d9c89')])
        style.configure('TCheckbutton', background='#182337', foreground='#e2e8f0', padding=4)
        style.map('TCheckbutton', background=[('active', '#182337')])
        page = ttk.Frame(root, padding=24)
        page.pack(fill='both', expand=True)
        heading = ttk.Frame(page)
        heading.pack(fill='x')
        assets = Path(__file__).with_name('assets')
        try:
            self.header_icon = tk.PhotoImage(file=str(assets / 'checkpoint-manager-32.png'))
            ttk.Label(heading, image=self.header_icon).pack(side='left', padx=(0, 12))
            if os.name == 'nt':
                root.iconbitmap(str(assets / 'checkpoint-manager.ico'))
            else:
                root.iconphoto(True, self.header_icon)
        except tk.TclError:
            self.header_icon = None
        ttk.Label(heading, text='Git Checkpoint Manager', style='Title.TLabel').pack(side='left')
        ttk.Label(page, text='Checkpoint cục bộ • Push thủ công • Hai repository riêng biệt', style='Muted.TLabel').pack(anchor='w', pady=(4, 16))
        toolbar = ttk.Frame(page)
        toolbar.pack(fill='x', pady=(0, 10))
        ttk.Label(toolbar, text='Quét mỗi').pack(side='left')
        ttk.Spinbox(toolbar, from_=10, to=3600, width=6, textvariable=self.interval_var).pack(side='left', padx=8)
        ttk.Label(toolbar, text='giây').pack(side='left')
        ttk.Button(toolbar, text='Áp dụng', command=self.apply_interval).pack(side='left', padx=8)
        ttk.Button(toolbar, text='Bật tự commit cả hai', style='Accent.TButton', command=self.resume_all).pack(side='right')
        ttk.Button(toolbar, text='Tạm dừng tất cả', command=self.pause_all).pack(side='right', padx=8)
        mode_row = ttk.Frame(page)
        mode_row.pack(fill='x', pady=(0, 3))
        self.activity_light = StatusLight(mode_row)
        self.activity_light.pack(side='left', padx=(0, 5))
        ttk.Label(mode_row, textvariable=self.mode_var, style='Status.TLabel').pack(side='left')
        ttk.Label(page, textvariable=self.countdown_var, style='Muted.TLabel').pack(anchor='w', pady=(0, 10))
        bridge_panel = ttk.Frame(page, padding=(15, 11), style='Panel.TFrame')
        bridge_panel.pack(fill='x', pady=(0, 12))
        bridge_title = ttk.Frame(bridge_panel, style='Panel.TFrame')
        bridge_title.pack(fill='x')
        ttk.Label(bridge_title, text='Blender MCP', style='Repo.TLabel').pack(side='left')
        self.blender_light = StatusLight(bridge_title, panel=True)
        self.blender_light.pack(side='left', padx=16)
        self.blender_light.set('idle', 'Đang kiểm tra…')
        ttk.Button(bridge_title, text='Kiểm tra ngay', command=self.refresh_blender).pack(side='right')
        ttk.Button(bridge_title, text='Chạy Blender MCP', style='Accent.TButton', command=self.start_blender).pack(side='right', padx=8)
        ttk.Label(bridge_panel, textvariable=self.bridge_detail, style='Panel.TLabel', wraplength=1010).pack(anchor='w', pady=(7, 0))
        shortcuts = ttk.Frame(bridge_panel, style='Panel.TFrame')
        shortcuts.pack(fill='x', pady=(7, 0))
        for key, label in VIEW_LABELS.items():
            group = ttk.Frame(shortcuts, style='Panel.TFrame')
            group.pack(side='left', padx=(0, 14))
            button = ttk.Button(group, text='Mở ' + label, command=lambda view=key: self.open_blender_view(view))
            button.pack(side='left', padx=(0, 4))
            self.view_buttons[key] = button
            copy_button = ttk.Button(group, text='Copy path', command=lambda view=key: self.copy_blender_view_path(view))
            copy_button.pack(side='left')
            self.view_copy_buttons[key] = copy_button
        ttk.Label(shortcuts, text='MCP kiểm tra mỗi 3 giây', style='Panel.TLabel').pack(side='right')
        for index, config in enumerate(self.configs):
            panel = ttk.Frame(page, style='Panel.TFrame', padding=15)
            panel.pack(fill='x', pady=(0, 12))
            title = ttk.Frame(panel, style='Panel.TFrame')
            title.pack(fill='x')
            ttk.Label(title, text=config.name, style='Repo.TLabel').pack(side='left')
            light = StatusLight(title, panel=True)
            light.pack(side='left', padx=16)
            light.set('idle', 'Tạm dừng')
            self.repo_lights.append(light)
            ttk.Checkbutton(title, text='Tự commit', variable=self.auto_vars[index], command=lambda i=index: self.toggle_auto(i)).pack(side='right')
            ttk.Label(panel, text=str(config.path), style='Panel.TLabel').pack(anchor='w', pady=(4, 8))
            metrics = ttk.Frame(panel, style='Panel.TFrame')
            metrics.pack(fill='x', pady=(0, 7))
            ttk.Label(metrics, textvariable=self.uncommitted_vars[index], style='Metric.TLabel').pack(side='left', padx=(0, 25))
            pending = ttk.Label(metrics, textvariable=self.pending_push_vars[index], style='Metric.TLabel')
            pending.pack(side='left', padx=(0, 25))
            self.pending_push_labels.append(pending)
            ttk.Label(metrics, textvariable=self.remote_extra_vars[index], style='Panel.TLabel').pack(side='left')
            ttk.Label(panel, textvariable=self.repo_text[index], style='Panel.TLabel', justify='left', wraplength=1010).pack(anchor='w')
            buttons = ttk.Frame(panel, style='Panel.TFrame')
            buttons.pack(fill='x', pady=(10, 0))
            for label, callback in [
                ('Làm mới', self.refresh), ('Xem thay đổi', lambda i=index: self.show_changes(i)),
                ('Commit ngay', lambda i=index: self.commit_now(i)), ('Push', lambda i=index: self.push_now(i)),
            ]:
                button = ttk.Button(buttons, text=label, command=callback)
                button.pack(side='left', padx=(0, 8))
                self.action_buttons.append(button)
            if config.require_private:
                ttk.Label(panel, text='MD2: Push kiểm tra repo PRIVATE. Dữ liệu gốc trong Release snapshot không được cập nhật bởi Git commit/push.', style='Panel.TLabel', foreground='#fbbf24', wraplength=1010).pack(anchor='w', pady=(10, 0))
        ttk.Label(page, text='NHẬT KÝ', style='Muted.TLabel').pack(anchor='w', pady=(0, 6))
        self.log_widget = scrolledtext.ScrolledText(page, height=8, background='#101a2c', foreground='#cbd5e1', insertbackground='white', font=('Consolas', 9), relief='flat', wrap='word')
        self.log_widget.pack(fill='both', expand=True)
        self.log_widget.configure(state='disabled')
        ttk.Label(page, text='Đóng app = dừng hẹn giờ. Bỏ qua file đang ghi; không có thay đổi hợp lệ thì không tạo commit.', style='Muted.TLabel').pack(side='bottom', anchor='w', pady=(10, 0), before=self.log_widget)

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
            elif kind == 'details':
                title, text = value
                window = tk.Toplevel(self.root)
                window.title(title)
                window.geometry('980x620')
                text_widget = scrolledtext.ScrolledText(window, wrap='none', font=('Consolas', 10))
                text_widget.pack(fill='both', expand=True)
                text_widget.insert('1.0', text)
                text_widget.configure(state='disabled')
            else:
                for index, snapshot, message, disable, committed in value:
                    if disable:
                        self.repo_issues[index] = True
                        self.auto_vars[index].set(False)
                        self.auto_permits[index].clear()
                        self.repo_text[index].set('Cần kiểm tra: ' + message[:400])
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
                        self.pending_push_labels[index].configure(foreground='#fbbf24' if known and int(counts[0]) else '#34d399' if known else '#94a3b8')
                        self.repo_text[index].set(
                            f'Nhánh: {snapshot.branch or "DETACHED"}   •   HEAD: {snapshot.head[:8]}   •   Upstream: {snapshot.upstream or "chưa có"}\n'
                            f'Hợp lệ: {len(snapshot.eligible)} file   |   Bỏ qua: {excluded}   |   Đã stage: {"có" if snapshot.staged else "không"}   •   Checkpoint trong app: {self.last_checkpoint[index]}'
                        )
                    if message:
                        self.log(f'{self.configs[index].name}: {message}')
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
            messagebox.showerror('Khoảng quét', 'Chọn số giây từ 10 đến 3600.', parent=self.root)
            return
        self.schedule.interval = seconds
        self.schedule.consume(self.clock())
        path = self.state_dir / 'settings.json'
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps({'interval_seconds': seconds}), encoding='utf-8')
        temporary.replace(path)
        self.log(f'Đã đặt khoảng quét: {seconds} giây. Không có thời gian chờ 60 giây.')

    def _update_mode(self):
        count = sum(variable.get() for variable in self.auto_vars)
        self.mode_var.set(f'TỰ COMMIT ĐANG BẬT: {count}/{len(self.configs)} REPO • Push vẫn thủ công' if count else 'ĐÃ TẠM DỪNG • Chỉ quét, không tự commit')
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
        if not snapshot or self.busy:
            return
        if messagebox.askyesno('Commit ngay', f'{self.configs[index].name}: commit các thay đổi hợp lệ trên nhánh {snapshot.branch}?\nFile staged sẵn sẽ không bị lấy vào commit tự động.', parent=self.root):
            flags = [False] * len(self.configs)
            flags[index] = True
            anchors = self._anchors()
            self._submit(lambda: self._cycle([index], flags, anchors), indices=[index], label='Đang commit')

    def push_now(self, index):
        snapshot = self.snapshots[index]
        if not snapshot or self.busy:
            return
        identity = snapshot.identity
        def job():
            message = self.repositories[index].push(expected_identity=identity)
            return [(index, self.repositories[index].scan(), message, False, False)]
        self.log(f'{self.configs[index].name}: đang Push theo yêu cầu của bạn…')
        self._submit(job, indices=[index], label='Đang Push')

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
        except (OSError, ValueError, tk.TclError) as error:
            self.log(f'Không copy được path {label}: {error}')

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
    except RuntimeError as error:
        messagebox.showinfo('Git Checkpoint Manager', str(error), parent=root)
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
