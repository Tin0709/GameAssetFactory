"""Git operations for the desktop manager. No operation runs on import."""
from dataclasses import dataclass
from datetime import datetime
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from .commit_message import staged_message


class RepoError(RuntimeError):
    """An operation failed; work/index are intentionally left intact."""


class RepoBlocked(RepoError):
    """The operation needs user attention before trying again."""


class FilesChanging(RepoBlocked):
    """Transient: try the next scheduled scan without staging anything."""


def redact(text):
    text = re.sub(r'(https?://)[^/\s@]+@', r'\1[redacted]@', str(text))
    text = re.sub(r'\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+)\b', '[redacted]', text)
    for key in ('GH_TOKEN', 'GITHUB_TOKEN'):
        if os.environ.get(key):
            text = text.replace(os.environ[key], '[redacted]')
    return text


def github_repository(url):
    match = re.fullmatch(r'(?:https://github\.com/|git@github\.com:)([\w.-]+/[\w.-]+?)(?:\.git)?/?', url)
    if not match:
        raise RepoBlocked('Không thể xác minh repo GitHub từ URL đã cấu hình.')
    return match.group(1)


def git_environment():
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='Never', GIT_OPTIONAL_LOCKS='0')
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_LFS_SKIP_PUSH'):
        env.pop(name, None)
    return env


@dataclass(frozen=True)
class RepoConfig:
    name: str
    path: Path
    expected_remote: str
    require_private: bool = False


@dataclass(frozen=True)
class Change:
    code: str
    path: str
    original: str = ''
    reason: str = ''


@dataclass(frozen=True)
class Snapshot:
    branch: str
    head: str
    changes: tuple
    signatures: tuple
    upstream: str = ''
    ahead_behind: str = ''
    index_changes: bool = False

    @property
    def identity(self):
        return self.branch, self.head

    @property
    def staged(self):
        return self.index_changes or any(change.code[0] not in ' ?' for change in self.changes)

    @property
    def eligible(self):
        return tuple(change for change in self.changes if not change.reason)


class AutoSchedule:
    def __init__(self, interval=10, now=None):
        self.interval = max(10, int(interval))
        self.last = time.monotonic() if now is None else now

    def due(self, now=None):
        return (time.monotonic() if now is None else now) >= self.last + self.interval

    def consume(self, now=None):
        self.last = time.monotonic() if now is None else now


def exclusion(path, untracked):
    parts = PurePosixPath(path.replace('\\', '/')).parts
    name = parts[-1].lower() if parts else ''
    if (name.startswith('.env') and name not in {'.env.example', '.env.sample'}) or name in {
        'id_rsa', 'id_ed25519', 'credentials.json', 'secrets.json', 'token.json', '.git-credentials',
    } or name.endswith(('.pem', '.key', '.p12', '.pfx')):
        return 'Thông tin đăng nhập / khóa riêng — cần kiểm tra thủ công'
    if untracked and (any(part.lower() in {
        '__pycache__', '.godot', '.validation', '.venv', 'venv', '.pytest_cache', '.git',
    } for part in parts) or re.search(r'\.blend\d+$', name) or name.endswith(('.pyc', '.pyo', '.tmp', '.bak', '.log'))):
        return 'Cache / bản sao tạm chưa được Git theo dõi'
    return ''


class GitRepository:
    def __init__(self, config, stability_seconds=0.25):
        self.config = config
        self.path = Path(config.path).resolve()
        self.stability_seconds = stability_seconds

    def _run(self, *args, data=None, check=True, timeout=120):
        env = git_environment()
        try:
            result = subprocess.run(
                ['git', '-c', 'credential.interactive=never', *args], cwd=self.path,
                env=env, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            raise RepoError('Git quá thời gian chờ; đã tạm dừng tự commit. Kiểm tra tiến trình Git và index trước khi tiếp tục.') from None
        except OSError as error:
            raise RepoError(redact(str(error))) from None
        if check and result.returncode:
            details = (result.stderr or result.stdout).decode('utf-8', errors='replace').strip()
            raise RepoError(redact(details)[:4000] or 'Lệnh Git thất bại.')
        return result

    def _text(self, *args, check=True):
        return self._run(*args, check=check).stdout.decode('utf-8', errors='replace').strip()

    def _git_dir(self):
        return Path(self._text('rev-parse', '--absolute-git-dir'))

    def _guard(self, snap, expected_identity=None):
        root = Path(self._text('rev-parse', '--show-toplevel')).resolve()
        if root != self.path:
            raise RepoBlocked('Đường dẫn không phải gốc repository đã chọn.')
        git_dir = self._git_dir()
        markers = ('index.lock', 'HEAD.lock', 'packed-refs.lock', 'config.lock', 'shallow.lock',
                   'MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD',
                   'rebase-apply', 'rebase-merge', 'sequencer', 'BISECT_LOG')
        if any((git_dir / marker).exists() for marker in markers) or any((git_dir / 'refs').rglob('*.lock')):
            raise RepoBlocked('Git đang khóa hoặc đang merge/rebase; hãy hoàn tất thao tác đó trước.')
        if not snap.branch:
            raise RepoBlocked('Detached HEAD — hãy chọn nhánh bằng công cụ Git của bạn trước.')
        if expected_identity is not None and snap.identity != expected_identity:
            raise RepoBlocked('Nhánh hoặc HEAD đã đổi ngoài app; tự commit đã dừng để bạn kiểm tra.')
        if snap.staged:
            raise RepoBlocked('Đã có file staged; app giữ nguyên index và chờ bạn xử lý thủ công.')

    def scan(self):
        branch = self._text('symbolic-ref', '--quiet', '--short', 'HEAD', check=False)
        head = self._text('rev-parse', '--verify', 'HEAD', check=False)
        if not head:
            raise RepoBlocked('Repository chưa có commit đầu tiên; hãy khởi tạo thủ công trước.')
        rows = self._run('status', '--porcelain=v1', '-z', '--untracked-files=all').stdout.split(b'\0')
        changes, signatures = [], []
        index = 0
        while index < len(rows):
            row = rows[index]
            index += 1
            if not row:
                continue
            code = row[:2].decode('ascii')
            path = os.fsdecode(row[3:])
            original = ''
            if 'R' in code or 'C' in code:
                original = os.fsdecode(rows[index])
                index += 1
            reason = exclusion(path, code == '??')
            candidate = self.path / path
            if candidate.is_dir():
                reason = reason or 'Thư mục Git lồng / submodule — cần xử lý thủ công'
            changes.append(Change(code, path, original, reason))
            for name in (path, original):
                if not name:
                    continue
                try:
                    info = (self.path / name).lstat()
                    signature = info.st_size, info.st_mtime_ns, info.st_mode
                except FileNotFoundError:
                    signature = None
                signatures.append((name, signature))
        upstream = self._text('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}', check=False)
        counts = self._text('rev-list', '--left-right', '--count', 'HEAD...@{upstream}', check=False) if upstream else ''
        index_changes = bool(self._run('diff', '--cached', '--name-only', '--ita-visible-in-index', '-z').stdout)
        return Snapshot(branch, head, tuple(changes), tuple(signatures), upstream, counts, index_changes)

    def _large_file_preflight(self, names):
        payload = b'\0'.join(os.fsencode(name) for name in names) + b'\0'
        fields = self._run('check-attr', '-z', '--stdin', 'filter', data=payload).stdout.split(b'\0')
        filters = {os.fsdecode(fields[i]): fields[i + 2] for i in range(0, len(fields) - 1, 3)}
        needs_lfs = False
        for name in names:
            path = self.path / name
            if not path.is_file() or path.is_symlink():
                continue
            is_lfs = filters.get(name) == b'lfs'
            needs_lfs |= is_lfs
            if path.stat().st_size > 100 * 1024 * 1024 and not is_lfs:
                raise RepoBlocked(f'File vượt 100 MiB chưa có Git LFS: {name}. App không tự đổi tracking.')
        if needs_lfs and self._run('lfs', 'version', check=False).returncode:
            raise RepoBlocked('Cần Git LFS cho các asset đã cấu hình; app không bỏ qua bộ lọc.')

    def checkpoint(self, expected_identity=None):
        before = self.scan()
        self._guard(before, expected_identity)
        if not before.eligible:
            return before
        names = sorted({name for change in before.eligible for name in (change.path, change.original) if name})
        self._large_file_preflight(names)
        time.sleep(self.stability_seconds)
        current = self.scan()
        self._guard(current, before.identity)
        if current.changes != before.changes or current.signatures != before.signatures:
            raise FilesChanging('File đang thay đổi; bỏ qua lượt này và kiểm tra lại ở lượt quét tiếp theo.')
        payload = b'\0'.join(os.fsencode(name) for name in names) + b'\0'
        self._run('--literal-pathspecs', 'add', '-A', '--pathspec-from-file=-', '--pathspec-file-nul', data=payload, timeout=600)
        # A failed validation/commit deliberately leaves staged data available for review.
        if (self._text('symbolic-ref', '--quiet', '--short', 'HEAD', check=False), self._text('rev-parse', 'HEAD')) != before.identity:
            raise RepoBlocked('HEAD đổi trong khi stage; giữ nguyên index và dừng để kiểm tra.')
        actual = set(filter(None, self._run('diff', '--cached', '--name-only', '-z', '--no-renames').stdout.split(b'\0')))
        if not actual.issubset({os.fsencode(name) for name in names}):
            raise RepoBlocked('Index chứa thay đổi ngoài danh sách đã chọn; giữ nguyên để kiểm tra.')
        if not actual:
            return self.scan()
        guard = Path(__file__).resolve().parents[1] / 'git_large_file_guard.py'
        validation = subprocess.run([sys.executable, str(guard), '--repo', str(self.path)],
                                    cwd=self.path, env=git_environment(), capture_output=True,
                                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), timeout=120)
        if validation.returncode:
            raise RepoBlocked(redact(validation.stderr.decode(errors='replace')) or 'Kiểm tra staged/LFS thất bại.')
        stamp = datetime.now().astimezone().isoformat(timespec='seconds')
        message = staged_message(self._run, self.config.name, before.branch, stamp)
        self._run('-c', 'i18n.commitEncoding=UTF-8', 'commit', '--file=-',
                  data=message.encode('utf-8', errors='backslashreplace'), timeout=600)
        return self.scan()

    def _push_target(self, snapshot):
        remote = self._text('config', '--get', f'branch.{snapshot.branch}.remote', check=False)
        merge = self._text('config', '--get', f'branch.{snapshot.branch}.merge', check=False)
        if not remote or remote == '.' or not merge.startswith('refs/heads/'):
            raise RepoBlocked('Nhánh chưa có upstream từ xa hợp lệ; app không tự tạo hoặc đổi upstream.')
        urls = self._text('remote', 'get-url', '--push', '--all', remote).splitlines()
        if len(urls) != 1 or urls[0] != self.config.expected_remote:
            raise RepoBlocked('Remote Push không trùng đích đã cấu hình; hãy kiểm tra trước.')
        if self._text('config', '--bool', '--get', f'remote.{remote}.mirror', check=False) == 'true':
            raise RepoBlocked('Không hỗ trợ remote mirror; chỉ push nhánh upstream hiện tại.')
        return remote, merge, urls[0]

    def verify_private(self, url):
        repository = github_repository(url)
        credential = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
        if not credential:
            response = self._run('credential', 'fill', data=(f'protocol=https\nhost=github.com\npath={repository}.git\n\n').encode(), check=False)
            fields = dict(row.split('=', 1) for row in response.stdout.decode().splitlines() if '=' in row)
            credential = fields.get('password') if response.returncode == 0 else None
        if not credential:
            raise RepoBlocked('Không xác minh được repo riêng tư. Hãy đăng nhập GitHub bằng Git Credential Manager trước.')
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):
                return None
        request = urllib.request.Request(
            'https://api.github.com/repos/' + repository,
            headers={'Authorization': 'Bearer ' + credential, 'Accept': 'application/vnd.github+json',
                     'User-Agent': 'GAF-Checkpoint-Manager'},
        )
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=30) as response:
                metadata = json.load(response)
        except (urllib.error.URLError, ValueError, TimeoutError):
            raise RepoBlocked('GitHub chưa xác nhận được quyền riêng tư; Push MD2 đã bị chặn an toàn.') from None
        if metadata.get('private') is not True or metadata.get('full_name', '').casefold() != repository.casefold():
            raise RepoBlocked('Repo MD2 không được xác nhận là PRIVATE; không Push.')

    def push(self, expected_identity=None):
        snapshot = self.scan()
        self._guard(snapshot, expected_identity)
        target = self._push_target(snapshot)
        if self.config.require_private:
            self.verify_private(target[2])
        latest = self.scan()
        self._guard(latest, snapshot.identity)
        if self._push_target(latest) != target:
            raise RepoBlocked('Remote vừa thay đổi; đã dừng Push.')
        remote, merge, _ = target
        # A captured object ID avoids pushing a different HEAD if an external UI
        # changes branches after our final check. No force and no wildcard refs.
        result = self._run('push', '--porcelain', '--no-follow-tags', '--recurse-submodules=no', '--', remote, f'{snapshot.head}:{merge}', timeout=900)
        row = self._text('ls-remote', '--exit-code', '--', target[2], merge)
        if not row or row.split()[0] != snapshot.head:
            raise RepoError('Push hoàn tất nhưng ref từ xa không còn trùng commit vừa gửi; cần kiểm tra.')
        return f'Đã xác minh ref từ xa: {snapshot.head[:8]}. Push dùng hook hiện có; chưa kiểm tra độc lập toàn bộ LFS từ xa.\n' + redact(result.stdout.decode(errors='replace'))

    def details(self):
        snapshot = self.scan()
        lines = [f'{change.code} {change.path}' + (f'  [BỎ QUA: {change.reason}]' if change.reason else '') for change in snapshot.changes]
        diff = self._text('diff', '--stat')
        return '\n'.join(lines) + '\n\nTracked diff summary:\n' + diff
