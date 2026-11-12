"""Exercise the local UI transport without starting Chromium or touching Git."""
from contextlib import closing
import http.client
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from checkpoint_manager.web_ui import LocalUI


class LocalUITests(unittest.TestCase):
    def setUp(self):
        self.ui = LocalUI()
        self.addCleanup(self.ui.close)
        self.ui.publish({'ready': True})

    def request(self, method, path, headers=None, payload=None):
        with closing(http.client.HTTPConnection('127.0.0.1', self.ui.port, timeout=3)) as client:
            client.request(method, path, body=json.dumps(payload) if payload else None, headers=headers or {})
            response = client.getresponse()
            return response.status, response.read()

    def test_state_requires_session_token_and_local_host(self):
        self.assertEqual(self.request('GET', '/state')[0], 403)
        headers = {'X-Checkpoint-Token': self.ui.token}
        self.assertEqual(self.request('GET', '/state', headers), (200, b'{"ready": true}'))
        self.assertEqual(self.request('GET', '/state', dict(headers, Host='example.com'))[0], 403)

    def test_actions_reject_cross_origin_and_arbitrary_commands(self):
        headers = {'X-Checkpoint-Token': self.ui.token, 'Content-Type': 'application/json'}
        payload = {'action': 'godot'}
        self.assertEqual(self.request('POST', '/action', dict(headers, Origin='https://example.com'), payload)[0], 403)
        self.assertTrue(self.ui.actions.empty())
        headers['Origin'] = self.ui.origin
        self.assertEqual(self.request('POST', '/action', headers, {'action': 'exec', 'command': 'example'})[0], 400)
        self.assertEqual(self.request('POST', '/action', headers, payload)[0], 202)
        self.assertEqual(self.ui.actions.get_nowait(), payload)

    def test_assets_do_not_include_the_session_token(self):
        status, body = self.request('GET', '/')
        self.assertEqual(status, 200)
        self.assertIn(b'<title>DevDock</title>', body)
        self.assertNotIn(self.ui.token.encode(), body)
        status, icon = self.request('GET', '/devdock.ico')
        self.assertEqual(status, 200)
        self.assertTrue(icon.startswith(b'\x00\x00\x01\x00'))
        self.assertEqual(self.request('GET', '/../../desktop.py')[0], 404)
