"""Start the installed Blender Lab MCP1.0.3 bridge on loopback; no file saves."""
import importlib.util
import os
from pathlib import Path
import sys
import types
import bpy

addon = Path(os.environ.get('BLENDER_MCP_ADDON',
    str(Path(bpy.utils.user_resource('CONFIG')).parent / 'extensions/user_default/mcp')))
source = addon / 'mcp_to_blender_server.py'
if not source.is_file():
    raise RuntimeError('Install Blender Lab MCP1.0.3 or set BLENDER_MCP_ADDON to its add-on folder.')
host = os.environ.get('BLENDER_MCP_HOST', 'localhost')
if host not in ['localhost', '127.0.0.1']:
    raise ValueError('Blender Lab MCP1.0.3 uses IPv4; select localhost or127.0.0.1.')
port = int(os.environ.get('BLENDER_MCP_PORT', '9876'))
# Keep the installed add-on's relative imports available without enabling its
# preference-driven auto-start hook or colliding with another Blender session.
package_name = 'gaf_installed_blender_mcp'
package = types.ModuleType(package_name); package.__path__ = [str(addon)]
sys.modules[package_name] = package
spec = importlib.util.spec_from_file_location(package_name + '.mcp_to_blender_server', source)
bridge = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = bridge
spec.loader.exec_module(bridge)
bridge.start(host, port)
print(f'GAF_MCP_BRIDGE_READY {host}:{port}', flush=True)
if bpy.app.background:
    while bridge.is_running(): bridge.poll_blocking()
else:
    def poll():
        bridge.poll()
        return .05 if bridge.is_running() else None
    bpy.app.timers.register(poll, first_interval=.05)
