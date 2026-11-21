"""Test Blender MCP against the independent project candidate using its stdio protocol."""
import asyncio
import json
import os
from pathlib import Path
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main(app, blender, candidate):
    params=StdioServerParameters(command=app,args=["--transport","stdio"],env={**os.environ,"BLENDER_PATH":blender,"BLENDER_MCP_HOST":"127.0.0.1","BLENDER_MCP_PORT":"65173"})
    code = """
import bpy
s = bpy.context.scene
rig = s.objects['Scout Canon | Rig']
meshes = [o for o in s.objects if o.type == 'MESH']
assert meshes and all(o.parent == rig and o.parent_bone in rig.data.bones for o in meshes)
images = sorted((i.name, list(i.size)) for i in bpy.data.images if i.packed_file)
assert sum(sz == [64,64] for _,sz in images) >= 3
result={'scene':s.name,'meshes':len(meshes),'bones':len(rig.data.bones),'packed_images':images,
        'cameras':[m.name for m in s.timeline_markers]}
"""
    async with stdio_client(params) as (read,write):
        async with ClientSession(read,write) as session:
            await session.initialize()
            candidates=[t.name for t in (await session.list_tools()).tools if t.name.endswith("execute_blender_code_for_cli")]
            assert len(candidates)==1,candidates
            answer=await session.call_tool(candidates[0],{"blend_file":str(Path(candidate).resolve()),"code":code})
            assert not answer.isError,answer
            print(json.dumps(answer.structuredContent or [x.model_dump() for x in answer.content],indent=2,ensure_ascii=False))
asyncio.run(main(*sys.argv[1:]))


