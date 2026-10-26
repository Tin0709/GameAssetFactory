"""Start the pinned local Blender bridge and monitor read-only health checks."""
from dataclasses import dataclass, field
import http.client
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import threading
import time


SOURCE = 'git+https://projects.blender.org/lab/blender_mcp.git@v1.0.3#subdirectory=mcp'
PROBE_CODE = "result = {'gaf_manager_probe': True}"
MAX_RESPONSE = 256 * 1024


class BridgeError(RuntimeError):
    pass


@dataclass(frozen=True)
class BridgeConfig:
    http_host: str = '127.0.0.1'
    http_port: int = 8000
    addon_host: str = 'localhost'
    addon_port: int = 9876
    uvx_path: Path = field(default_factory=lambda: Path(os.environ.get('LOCALAPPDATA', str(Path.home() / 'AppData/Local'))) / 'Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.WinGet.Source_8wekyb3d8bbwe/uvx.exe')
    timeout: float = 1.6


@dataclass(frozen=True)
class BridgeStatus:
    server_ready: bool
    blender_ready: bool
    connected: bool
    label: str
    detail: str


class BlenderBridge:
    def __init__(self, state_dir, config=None):
        self.state_dir = Path(state_dir)
        self.config = config or BridgeConfig()
        self._process = None
        self._protocol = '2024-11-05'
        self._retry_tool_after = 0.0

    def _http(self, method, params=None):
        config = self.config
        request = {'jsonrpc': '2.0', 'id': 'gaf-health', 'method': method}
        if params is not None:
            request['params'] = params
        connection = http.client.HTTPConnection(config.http_host, config.http_port, timeout=config.timeout)
        deadline = time.monotonic() + config.timeout
        watchdog = None
        try:
            connection.connect()
            transport = connection.sock
            def expire():
                # Interrupt slow headers as well as slow body/chunk framing.
                # Keep the original socket reference even when HTTP/1.0 makes
                # HTTPConnection detach it while response.fp still owns it.
                try:
                    transport.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
            watchdog = threading.Timer(max(.001, deadline - time.monotonic()), expire)
            watchdog.daemon = True
            watchdog.start()
            connection.request('POST', '/', body=json.dumps(request).encode(), headers={
                'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream',
                'MCP-Protocol-Version': self._protocol,
            })
            response = connection.getresponse()
            if response.status != 200:
                raise BridgeError('HTTP MCP chưa phản hồi hợp lệ.')
            body = bytearray()
            sse = 'text/event-stream' in response.getheader('Content-Type', '')
            payload = None
            while len(body) <= MAX_RESPONSE:
                if response.isclosed():
                    break
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise BridgeError('HTTP MCP vượt thời gian kiểm tra.')
                transport.settimeout(remaining)
                chunk = response.read1(min(4096, MAX_RESPONSE + 1 - len(body)))
                if not chunk:
                    break
                body.extend(chunk)
                if sse:
                    # A valid SSE result need not wait for the server to close
                    # its event stream. Parse only complete events.
                    events = body.replace(b'\r\n', b'\n').split(b'\n\n')[:-1]
                    for event in events:
                        data = b'\n'.join(line[5:].lstrip() for line in event.splitlines() if line.startswith(b'data:'))
                        if data:
                            value = json.loads(data)
                            if isinstance(value, dict) and value.get('id') == 'gaf-health':
                                payload = value
                                break
                    if payload is not None:
                        break
            if len(body) > MAX_RESPONSE or time.monotonic() > deadline:
                raise BridgeError('HTTP MCP vượt giới hạn kiểm tra.')
            if not sse:
                payload = json.loads(body.decode('utf-8'))
            if not isinstance(payload, dict) or 'error' in payload or 'result' not in payload:
                raise BridgeError('HTTP không trả về kết quả MCP hợp lệ.')
            return payload['result']
        except (OSError, http.client.HTTPException, ValueError, StopIteration) as error:
            raise BridgeError('HTTP MCP chưa sẵn sàng hoặc hết thời gian phản hồi.') from error
        finally:
            if watchdog is not None:
                watchdog.cancel()
            connection.close()

    def _initialize(self):
        result = self._http('initialize', {
            'protocolVersion': self._protocol, 'capabilities': {},
            'clientInfo': {'name': 'gaf-checkpoint-status', 'version': '1.0'},
        })
        if not isinstance(result, dict) or result.get('serverInfo', {}).get('name') != 'blender-mcp':
            raise BridgeError('Cổng HTTP đang được một dịch vụ khác sử dụng, không phải Blender MCP.')
        self._protocol = result.get('protocolVersion', self._protocol)

    def _addon_probe(self):
        config = self.config
        request = json.dumps({'type': 'execute', 'code': PROBE_CODE, 'strict_json': True}).encode() + b'\0'
        try:
            with socket.create_connection((config.addon_host, config.addon_port), timeout=config.timeout) as connection:
                connection.settimeout(config.timeout)
                connection.sendall(request)
                response = bytearray()
                deadline = time.monotonic() + config.timeout
                while b'\0' not in response:
                    connection.settimeout(max(.01, deadline - time.monotonic()))
                    chunk = connection.recv(4096)
                    if not chunk:
                        return False
                    response.extend(chunk)
                    if len(response) > MAX_RESPONSE or time.monotonic() > deadline:
                        return False
            value = json.loads(response.partition(b'\0')[0])
            return value.get('status') == 'ok' and value.get('result', {}).get('gaf_manager_probe') is True
        except (OSError, ValueError, AttributeError):
            return False

    def _end_to_end(self):
        result = self._http('tools/call', {'name': 'execute_blender_code', 'arguments': {'code': PROBE_CODE}})
        if not isinstance(result, dict) or result.get('isError'):
            return False
        candidates = [result.get('structuredContent')]
        for content in result.get('content', []):
            if content.get('type') == 'text':
                try:
                    candidates.append(json.loads(content.get('text', '')))
                except ValueError:
                    pass
        return any(isinstance(value, dict) and value.get('status') == 'ok' and
                   isinstance(value.get('result'), dict) and value['result'].get('gaf_manager_probe') is True
                   for value in candidates)

    def probe(self):
        server_ready = False
        server_note = ''
        try:
            self._initialize()
            server_ready = True
        except BridgeError as error:
            server_note = str(error)
        blender_ready = self._addon_probe()
        if not server_ready:
            running = self._process is not None and self._process.poll() is None
            label = 'MCP đang khởi động…' if running else 'MCP chưa kết nối'
            return BridgeStatus(False, blender_ready, False, label, server_note + (' Blender đã phản hồi.' if blender_ready else ' Mở Blender và bật add-on MCP.'))
        if not blender_ready:
            return BridgeStatus(True, False, False, 'Chờ Blender / add-on', 'Server MCP đã chạy; Blender chưa phản hồi hoặc đang bận.')
        if time.monotonic() < self._retry_tool_after:
            return BridgeStatus(True, True, False, 'Đang chờ xác minh lại', 'Blender phản hồi; đang giãn nhịp thử lại kết nối qua HTTP.')
        try:
            connected = self._end_to_end()
        except BridgeError:
            connected = False
        if not connected:
            # Avoid accumulating requests if Blender becomes busy after the
            # direct preflight, or an external MCP targets a different socket.
            self._retry_tool_after = time.monotonic() + 15
            return BridgeStatus(True, True, False, 'Chưa xác minh kết nối MCP', 'Blender phản hồi trực tiếp nhưng lệnh qua HTTP MCP chưa thành công.')
        return BridgeStatus(True, True, True, 'Đã kết nối Blender', 'Server MCP và Blender đã phản hồi lệnh kiểm tra chỉ đọc.')

    def _port_open(self):
        try:
            with socket.create_connection((self.config.http_host, self.config.http_port), timeout=self.config.timeout):
                return True
        except OSError:
            return False

    def start(self):
        if self._process is not None and self._process.poll() is None:
            return 'MCP đã được app khởi động; đang chờ server sẵn sàng.'
        if self._port_open():
            self._initialize()
            return 'Blender MCP đã chạy; dùng server hiện có, không mở trùng.'
        config = self.config
        if not config.uvx_path.is_file():
            raise BridgeError('Không tìm thấy uvx tại đường dẫn đã cấu hình. Không có tiến trình nào được chạy.')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, BLENDER_MCP_HOST=config.addon_host, BLENDER_MCP_PORT=str(config.addon_port))
        args = [str(config.uvx_path), '--from', SOURCE, 'blender-mcp', '--transport', 'http',
                '--host', config.http_host, '--port', str(config.http_port)]
        try:
            with (self.state_dir / 'blender-mcp.stdout.log').open('ab') as stdout, (self.state_dir / 'blender-mcp.stderr.log').open('ab') as stderr:
                self._process = subprocess.Popen(args, env=env, cwd=self.state_dir,
                                                 stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                                 creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        except OSError as error:
            raise BridgeError('Không thể chạy uvx. Xem đường dẫn và quyền truy cập ứng dụng.') from error
        return 'Đã chạy Blender MCP v1.0.3 trong nền. Server tiếp tục chạy khi đóng app.'


class BridgeMonitor:
    """A separate worker with no Tk references; Git work cannot stall its probes."""
    def __init__(self, bridge, interval=3):
        self.bridge, self.interval = bridge, interval
        self.events = queue.Queue()
        self._stop = threading.Event()
        self._wake = threading.Event()
        self._start_requested = threading.Event()
        self._thread = threading.Thread(target=self._run, name='blender-mcp-monitor', daemon=True)
        self._thread.start()

    def request_start(self):
        if not self._stop.is_set():
            self._start_requested.set()
            self._wake.set()

    def refresh(self):
        self._wake.set()

    def _run(self):
        while not self._stop.is_set():
            cycle_started = time.monotonic()
            self._wake.clear()
            if self._start_requested.is_set():
                self._start_requested.clear()
                try:
                    self.events.put(('message', self.bridge.start()))
                except Exception as error:
                    self.events.put(('message', 'Không chạy MCP: ' + str(error)))
            if self._stop.is_set():
                break
            try:
                self.events.put(('status', self.bridge.probe()))
            except Exception:
                self.events.put(('status', BridgeStatus(False, False, False, 'Chưa đọc được trạng thái', 'Kiểm tra lại kết nối Blender MCP.')))
            self._wake.wait(max(.01, self.interval - (time.monotonic() - cycle_started)))

    def close(self):
        self._stop.set()
        self._wake.set()
        if threading.current_thread() is not self._thread:
            self._thread.join(timeout=.2)
