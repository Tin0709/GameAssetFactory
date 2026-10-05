import sys
sys.path.insert(0, r'C:/Users/ADMIN/AppData/Roaming/Blender Foundation/Blender/5.2/extensions/user_default')
from mcp import mcp_to_blender_server as bridge
bridge.use_log = True
bridge.start('localhost', 9876)
while bridge.is_running():
    bridge.poll_blocking()
