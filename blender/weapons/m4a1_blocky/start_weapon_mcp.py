import sys,importlib.util,types
pkg=types.ModuleType('mcp'); pkg.__path__=['C:/Users/ADMIN/AppData/Roaming/Blender Foundation/Blender/5.2/extensions/user_default/mcp']; sys.modules['mcp']=pkg
print('Starting MCP bridge',flush=True)
spec=importlib.util.spec_from_file_location('mcp.mcp_to_blender_server','C:/Users/ADMIN/AppData/Roaming/Blender Foundation/Blender/5.2/extensions/user_default/mcp/mcp_to_blender_server.py')
bridge=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=bridge
spec.loader.exec_module(bridge)
bridge.start('localhost',9876)
print('MCP bridge ready',flush=True)
while bridge.is_running(): bridge.poll_blocking()

