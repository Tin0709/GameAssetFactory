"""Protocol tests use local disposable servers, never the user's Blender."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import socketserver
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from checkpoint_manager.blender_bridge import BlenderBridge, BridgeConfig, BridgeError, BridgeMonitor
except ImportError:
    BlenderBridge = None


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(BlenderBridge, 'Blender bridge is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.server_name = 'blender-mcp'
        self.tool_ok = True
        self.addon_ok = True
        self.tool_calls = 0
        self.codes = []
        self.slow_stream = False
        self.fragment_utf8 = False
        owner = self
        class HTTPHandler(BaseHTTPRequestHandler):
            def do_POST(self):
                request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                if request['method'] == 'initialize':
                    value = {'serverInfo': {'name': owner.server_name, 'version': '1.0.3'}, 'protocolVersion': '2024-11-05', 'capabilities': {}}
                    if owner.fragment_utf8:
                        value['instructions'] = 'Kiểm tra 🌱'
                else:
                    owner.tool_calls += 1
                    owner.codes.append(request['params']['arguments']['code'])
                    value = {'content': [{'type': 'text', 'text': json.dumps({'status': 'ok' if owner.tool_ok else 'error', 'result': {'gaf_manager_probe': owner.tool_ok}})}]}
                payload = json.dumps({'jsonrpc': '2.0', 'id': request['id'], 'result': value}, ensure_ascii=False).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'text/event-stream' if owner.slow_stream or owner.fragment_utf8 else 'application/json')
                if not owner.slow_stream and not owner.fragment_utf8:
                    self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                if owner.fragment_utf8:
                    event = b'data: ' + payload + b'\n\n'
                    split = event.index('🌱'.encode()) + 1
                    self.wfile.write(event[:split]);self.wfile.flush();time.sleep(.03)
                    self.wfile.write(event[split:])
                elif owner.slow_stream:
                    try:
                        for byte in b'data: ' + payload + b'\n\n':
                            self.wfile.write(bytes([byte]));self.wfile.flush();time.sleep(.02)
                    except OSError:
                        pass
                else:
                    self.wfile.write(payload)
            def log_message(self, *args):
                pass
        class AddonHandler(socketserver.BaseRequestHandler):
            def handle(self):
                data = b''
                while b'\0' not in data:
                    chunk = self.request.recv(4096)
                    if not chunk:
                        return
                    data += chunk
                owner.codes.append(json.loads(data.rstrip(b'\0'))['code'])
                response = {'status': 'ok', 'result': {'gaf_manager_probe': owner.addon_ok}}
                self.request.sendall(json.dumps(response).encode() + b'\0')
        self.http = ThreadingHTTPServer(('127.0.0.1', 0), HTTPHandler)
        self.addon = socketserver.ThreadingTCPServer(('127.0.0.1', 0), AddonHandler)
        for server in [self.http, self.addon]:
            server.daemon_threads = True
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.addCleanup(server.server_close)
            self.addCleanup(server.shutdown)
        self.config = BridgeConfig(http_port=self.http.server_port, addon_port=self.addon.server_address[1], uvx_path=self.folder / 'uvx.exe', timeout=.4)
        self.bridge = BlenderBridge(self.folder, self.config)

    def test_healthy_requires_read_only_end_to_end_response(self):
        status = self.bridge.probe()
        self.assertTrue(status.connected)
        self.assertTrue(status.server_ready)
        self.assertTrue(status.blender_ready)
        self.assertEqual(self.tool_calls, 1)
        self.assertTrue(all(code == "result = {'gaf_manager_probe': True}" for code in self.codes))

    def test_server_without_addon_does_not_claim_connected(self):
        self.addon_ok = False
        status = self.bridge.probe()
        self.assertTrue(status.server_ready)
        self.assertFalse(status.connected)
        self.assertEqual(self.tool_calls, 0, 'Do not queue HTTP tool calls into a busy/unresponsive Blender')

    def test_addon_success_without_http_tool_success_is_not_connected(self):
        self.tool_ok = False
        self.assertFalse(self.bridge.probe().connected)

    def test_existing_mcp_is_reused_without_starting_a_process(self):
        with patch('subprocess.Popen', side_effect=AssertionError('must not spawn')):
            self.assertIn('đã', self.bridge.start().lower())

    def test_unrelated_listener_is_not_replaced(self):
        self.server_name = 'unrelated-service'
        with patch('subprocess.Popen', side_effect=AssertionError('must not spawn')):
            with self.assertRaises(BridgeError):
                self.bridge.start()

    def test_start_uses_pinned_argv_environment_and_no_shell(self):
        self.config = BridgeConfig(http_port=0, addon_port=9876, uvx_path=self.folder / 'uvx.exe', timeout=.1)
        self.config.uvx_path.write_bytes(b'fixture')
        bridge = BlenderBridge(self.folder, self.config)
        calls = []
        class Process:
            pid = 100
            def __init__(self, args, **kwargs):
                calls.append((args, kwargs))
            def poll(self):
                return None
        with patch('subprocess.Popen', Process):
            bridge.start()
            bridge.start()
        self.assertEqual(len(calls), 1)
        args, kwargs = calls[0]
        self.assertIn('git+https://projects.blender.org/lab/blender_mcp.git@v1.0.3#subdirectory=mcp', args)
        self.assertEqual(args[-6:], ['--transport', 'http', '--host', '127.0.0.1', '--port', '0'])
        self.assertEqual(kwargs['env']['BLENDER_MCP_HOST'], 'localhost')
        self.assertEqual(kwargs['env']['BLENDER_MCP_PORT'], '9876')
        self.assertFalse(kwargs.get('shell', False))

    def test_monitor_does_not_start_server_automatically(self):
        with patch.object(self.bridge, 'start', side_effect=AssertionError('only explicit clicks may start')):
            monitor = BridgeMonitor(self.bridge, interval=.02)
            self.addCleanup(monitor.close)
            event = monitor.events.get(timeout=3)
            self.assertEqual(event[0], 'status')
            self.assertTrue(event[1].connected)
            monitor.close()

    def test_slow_stream_cannot_extend_the_overall_http_deadline(self):
        self.slow_stream = True
        bridge = BlenderBridge(self.folder, BridgeConfig(http_port=self.http.server_port,
                               addon_port=self.addon.server_address[1], timeout=.1))
        started = time.monotonic()
        with self.assertRaises(BridgeError):
            bridge._initialize()
        self.assertLess(time.monotonic() - started, .35)

    def test_sse_packet_split_inside_utf8_does_not_drop_connection(self):
        self.fragment_utf8 = True
        self.bridge._initialize()


if __name__ == '__main__':
    unittest.main()
