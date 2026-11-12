"""Serve the Liquid Glass view locally and dispatch a fixed set of UI actions."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from hmac import compare_digest
import json
import os
from pathlib import Path
import queue
import secrets
import shutil
import subprocess
import tempfile
import threading

from dev import find_tool, godot_command

from .blender_views import VIEW_LABELS
from .core import redact


ASSETS = Path(__file__).with_name('web')
ROUTES = {'/': ('index.html', 'text/html; charset=utf-8'),
          '/app.js': ('app.js', 'text/javascript; charset=utf-8')}
REPO_ACTIONS = {'repo-refresh', 'changes', 'commit', 'push'}
SIMPLE_ACTIONS = {'godot', 'start-mcp', 'check-mcp', 'refresh', 'all-on', 'all-off'}
REPO_NAMES = {'gaf': 'GameAssetFactory', 'md2': 'MD2 Research', 'tacz': 'TaCZ Research'}


def valid_action(data):
    if not isinstance(data, dict) or not isinstance(data.get('action'), str):
        return False
    action = data['action']
    fields = set(data) - {'action'}
    if action in SIMPLE_ACTIONS:
        return not fields
    if action in REPO_ACTIONS | {'toggle'}:
        if data.get('repo') not in REPO_NAMES.values():
            return False
        if action == 'toggle':
            return fields == {'repo', 'enabled'} and type(data['enabled']) is bool
        return fields == {'repo'}
    if action in {'shortcut', 'copy-shortcut'}:
        return fields == {'view'} and isinstance(data['view'], str) and data['view'] in VIEW_LABELS
    if action == 'settings':
        return fields == {'seconds'} and type(data['seconds']) is int and 10 <= data['seconds'] <= 3600
    if action == 'theme':
        return fields == {'theme'} and data['theme'] in ('light', 'dark')
    if action in {'confirm', 'dismiss'}:
        return fields == {'dialog'} and isinstance(data['dialog'], str) and len(data['dialog']) <= 64
    return False


class LocalUI:
    def __init__(self):
        self.token = secrets.token_urlsafe(32)
        self.actions = queue.Queue(maxsize=24)
        self._state = b'{}'
        self._assets = {url: ((ASSETS / file).read_bytes(), content_type)
                        for url, (file, content_type) in ROUTES.items()}
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def setup(self):
                self.request.settimeout(4)
                super().setup()

            def log_message(self, *args):
                pass

            def _reply(self, status, body=b'', content_type='application/json; charset=utf-8'):
                self.send_response(status)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(body)))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Referrer-Policy', 'no-referrer')
                self.send_header('X-Content-Type-Options', 'nosniff')
                self.send_header('Content-Security-Policy',
                                 "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; "
                                 "img-src data:; connect-src 'self'; frame-ancestors 'none'; "
                                 "form-action 'none'; base-uri 'none'")
                self.end_headers()
                self.wfile.write(body)

            def _local(self):
                return self.headers.get('Host') == f'127.0.0.1:{owner.port}'

            def _authorized(self):
                supplied = self.headers.get('X-Checkpoint-Token', '')
                return supplied.isascii() and compare_digest(supplied, owner.token)

            def do_GET(self):
                if not self._local():
                    return self._reply(403)
                if self.path == '/state':
                    return self._reply(200, owner._state) if self._authorized() else self._reply(403)
                if self.path in owner._assets:
                    return self._reply(200, *owner._assets[self.path])
                self._reply(404)

            def do_POST(self):
                if not self._local() or self.headers.get('Origin') != owner.origin or not self._authorized():
                    return self._reply(403)
                if self.path != '/action':
                    return self._reply(404)
                if self.headers.get('Content-Type') != 'application/json':
                    return self._reply(415)
                try:
                    size = int(self.headers.get('Content-Length', 0))
                    if not 0 < size <= 4096:
                        return self._reply(400)
                    data = json.loads(self.rfile.read(size))
                    if not valid_action(data):
                        return self._reply(400)
                except (ValueError, OSError, RecursionError):
                    return self._reply(400)
                try:
                    owner.actions.put_nowait(data)
                except queue.Full:
                    return self._reply(429)
                self._reply(202)

        self._server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.port = self._server.server_port
        self.origin = f'http://127.0.0.1:{self.port}'
        self._thread = threading.Thread(target=self._server.serve_forever, kwargs={'poll_interval': .1},
                                        name='checkpoint-local-ui', daemon=True)
        self._thread.start()

    def publish(self, state):
        self._state = json.dumps(state, ensure_ascii=False).encode('utf-8')

    def close(self):
        self._server.shutdown()
        self._server.server_close()


class WebDialog:
    def __init__(self):
        self.state = None
        self.callback = None

    @property
    def active(self):
        return self.state is not None

    def show_details(self, title, text):
        self.state = dict(id=secrets.token_urlsafe(16), kind='details', title=title, text=text)
        self.callback = None

    def show_confirm(self, title, message, callback, *, kind='commit', private=False):
        self.state = dict(id=secrets.token_urlsafe(16), kind=kind, title=title, text=message, private=private)
        self.callback = callback

    def close(self):
        self.state = None
        self.callback = None

    def respond(self, identifier, accept):
        if self.state is None or self.state['id'] != identifier:
            return
        callback = self.callback
        if not accept or callback is None or callback() is not False:
            self.close()


class WebNotifications:
    def __init__(self):
        self.state = None
        self.serial = 0

    def show(self, title, detail, kind='info'):
        self.serial += 1
        self.state = dict(id=self.serial, title=redact(title), detail=redact(detail)[:1200], kind=kind)

    def close(self):
        self.state = None


def find_browser():
    for name in ('msedge', 'chrome', 'chromium', 'google-chrome'):
        if executable := shutil.which(name):
            return Path(executable)
    if os.name == 'nt':
        for variable in ('ProgramFiles(x86)', 'ProgramFiles', 'LOCALAPPDATA'):
            if directory := os.environ.get(variable):
                for relative in ('Microsoft/Edge/Application/msedge.exe', 'Google/Chrome/Application/chrome.exe'):
                    candidate = Path(directory) / relative
                    if candidate.is_file():
                        return candidate
    return None


class WebWindow:
    """Run the HTML window while keeping Tk and Git on their existing threads."""
    def __init__(self, app, browser):
        self.app = app
        self.theme_path = app.state_dir / 'theme.txt'
        try:
            self.theme = self.theme_path.read_text(encoding='utf-8').strip()
        except OSError:
            self.theme = 'dark'
        self.theme = 'light' if self.theme == 'light' else 'dark'
        self.godot_ready = self._godot_available()
        self.ui = LocalUI()
        self.profile = tempfile.TemporaryDirectory(dir=app.state_dir, prefix='liquid-glass-', ignore_cleanup_errors=True)
        try:
            with (app.state_dir / 'browser-window.log').open('ab') as output:
                self.process = subprocess.Popen(
                    [str(browser), f'--user-data-dir={self.profile.name}',
                     '--no-first-run', '--no-default-browser-check', '--disable-background-mode', '--window-size=1400,980',
                     f'--app={self.ui.origin}/#{self.ui.token}'],
                    stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                )
        except OSError:
            self.ui.close()
            self.profile.cleanup()
            raise
        app.dialog = WebDialog()
        app.notifications = WebNotifications()
        self._poll()

    def _poll(self):
        app = self.app
        if app.closed or app.closing:
            return
        if self.process.poll() is not None:
            app.close()
            return
        while not self.ui.actions.empty():
            self._dispatch(self.ui.actions.get_nowait())
        self.ui.publish(self._snapshot())
        app.after_ids['web'] = app.root.after(180, self._poll)

    @staticmethod
    def _godot_available():
        try:
            godot_command(find_tool('godot'), scene=None, editor=False, headless=False)
            return True
        except (OSError, ValueError):
            return False

    def _snapshot(self):
        app = self.app
        repos = {}
        keys = {name: key for key, name in REPO_NAMES.items()}
        for index, config in enumerate(app.configs):
            if config.name not in keys:
                continue
            key, snapshot = keys[config.name], app.snapshots[index]
            ahead, behind = None, None
            if snapshot and len(counts := snapshot.ahead_behind.split()) == 2 and all(n.isdecimal() for n in counts):
                ahead, behind = map(int, counts)
            repos[key] = dict(path=str(config.path), enabled=app.auto_vars[index].get(),
                              issue=app.repo_issues[index], message=app.repo_text[index].get(),
                              branch=app.branch_vars[index].get(), head=app.head_detail_vars[index].get(),
                              upstream=app.upstream_detail_vars[index].get(), checkpoint=app.last_checkpoint[index],
                              changed=len(snapshot.changes) if snapshot else None, ahead=ahead, behind=behind,
                              eligible=len(snapshot.eligible) if snapshot else None,
                              ignored=len(snapshot.changes) - len(snapshot.eligible) if snapshot else None,
                              staged=snapshot.staged if snapshot else None)
        bridge = app.bridge_status
        gameplay = app.gameplay_process
        godot = dict(available=self.godot_ready, running=gameplay is not None and gameplay.poll() is None)
        return dict(theme=self.theme, interval=app.schedule.interval, busy=app.busy,
                    remaining=max(0, round(app.schedule.last + app.schedule.interval - app.clock())),
                    repos=repos, logs=list(app.recent_log), notice=app.notifications.state, godot=godot,
                    dialog=app.dialog.state, bridge=dict(label=bridge.label, detail=bridge.detail,
                                                        connected=bridge.connected, starting=app.bridge_starting))

    def _dispatch(self, data):
        app = self.app
        action = data['action']
        simple = {'godot': app.open_main_gameplay, 'start-mcp': app.start_blender,
                  'check-mcp': app.refresh_blender, 'all-on': app.resume_all, 'all-off': app.pause_all}
        if action in simple:
            simple[action]()
        elif action == 'refresh':
            self.godot_ready = self._godot_available()
            app.refresh()
            app.refresh_blender()
        elif action == 'settings':
            app.interval_var.set(str(data['seconds']))
            app.apply_interval()
        elif action == 'theme':
            self.theme = data['theme']
            try:
                self.theme_path.write_text(self.theme, encoding='utf-8')
            except OSError:
                app.notifications.show('Không lưu được giao diện', 'Chủ đề chỉ áp dụng cho cửa sổ hiện tại.', kind='error')
        elif action in {'confirm', 'dismiss'}:
            app.dialog.respond(data['dialog'], action == 'confirm')
        elif action == 'shortcut':
            app.open_blender_view(data['view'])
        elif action == 'copy-shortcut':
            app.copy_blender_view_path(data['view'], browser=True)
        else:
            self._repo_action(action, data)

    def _repo_action(self, action, data):
        app = self.app
        index = next((i for i, config in enumerate(app.configs) if config.name == data['repo']), None)
        if index is None or app.dialog.active:
            return
        if action == 'toggle':
            app.auto_vars[index].set(data['enabled'])
            app.toggle_auto(index)
        elif action == 'repo-refresh':
            app.refresh_repository(index)
        elif action == 'changes':
            app.show_changes(index)
        elif action == 'commit':
            app.commit_now(index)
        elif action == 'push':
            snapshot = app.snapshots[index]
            if snapshot is None or app.busy:
                return
            config = app.configs[index]
            identity = snapshot.identity

            def push():
                return app.push_now(index, expected_identity=identity, confirmed=True)

            app.dialog.show_confirm(f'Push · {config.name}', f'Push nhánh {snapshot.branch} lên remote đã cấu hình?',
                                    push, kind='push', private=config.require_private)

    def close(self):
        self.ui.close()
        self.profile.cleanup()
