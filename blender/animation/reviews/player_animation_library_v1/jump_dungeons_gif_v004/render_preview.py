"""Render only the additive V004 scene in the connected foreground Blender."""
import bpy
from pathlib import Path

OUT = Path(__file__).resolve().parent
FRAMES = OUT.parents[4] / '.validation/jump_dungeons_gif_v004/frames'


def batch(view, start, end):
    scene = bpy.data.scenes['JGIF4_JUMP_LAND_REVIEW']
    assert not bpy.app.background
    assert bpy.context.window.scene == scene
    target = FRAMES / view.lower()
    target.mkdir(parents=True, exist_ok=True)
    old_camera, old_path, old_frame = scene.camera, scene.render.filepath, scene.frame_current
    scene.camera = bpy.data.objects['JGIF4_' + view]
    try:
        for frame in range(start, end + 1):
            scene.frame_set(frame)
            scene.render.filepath = str(target / ('%03d.png' % frame))
            bpy.ops.render.render(write_still=True, scene=scene.name)
    finally:
        scene.camera, scene.render.filepath = old_camera, old_path
        scene.frame_set(old_frame)
    return {'view': view, 'frames': [start, end], 'folder': str(target)}
