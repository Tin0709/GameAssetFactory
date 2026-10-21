"""Essential native deformation, preservation and review-control checks."""
import bpy
import json
import math
import sys
import time
from pathlib import Path
from mathutils import Vector

D = Path(__file__).resolve().parent; P = D.parent; R = D.parents[4]
E = R / '.validation/md2_grass_wind_v001'
sys.path[:0] = [str(D), str(P), str(P / 'tall_grass_md2_v001')]
from flower_preservation import compare, mesh_content
from wind_nodes import CONTROLS
import grass_library_ui as static_ui
import wind_review_ui as ui

target = Path(sys.argv[sys.argv.index('--') + 1]) if '--' in sys.argv else E / 'dungeons_ground_style_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(target)); scene = bpy.context.scene
static_ui.register(); info = ui.record(); controller = bpy.data.objects[info['controller']]
original_meshes = json.loads((E / 'source_grass_meshes.json').read_text())
for name, expected in original_meshes.items():
    assert json.loads(json.dumps(mesh_content(bpy.data.objects[name].data))) == expected, name
for name in ['ViewLayer', 'Short Grass MD2', 'Tall Grass MD2']:
    bpy.context.window.view_layer = scene.view_layers[name]; bpy.context.view_layer.update()
errors = compare(json.loads((E / 'before_native.json').read_text()))
assert not errors, errors

def reset():
    for key, (value, *_rest) in CONTROLS.items(): controller[key] = value
    controller.update_tag()
def set_control(key, value):
    controller[key] = value; controller.update_tag(); bpy.context.view_layer.update()
def sample(obj, seconds):
    fps = scene.render.fps / scene.render.fps_base; frame = seconds * fps
    scene.frame_set(int(frame), subframe=frame % 1.)
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    result = [v.co.copy() for v in mesh.vertices]
    evaluated.to_mesh_clear(); return result
def error(a, b): return max((x-y).length for x,y in zip(a,b))
def rest(obj): return [v.co.copy() for v in obj.data.vertices]

ui.select(bpy.context, 'Field')
masters = [bpy.data.objects[n] for n in info['masters']]
root_error = 0.; width_error = 0.; largest = 0.
for obj in masters:
    ui.select(bpy.context, obj['wind_source'])
    base = rest(obj); mask = obj.data.attributes['md2_wind_t']
    for seconds in [0., 5., 10., 15., 20.]:
        posed = sample(obj, seconds)
        assert len(posed) == len(base)
        for i, (a, b) in enumerate(zip(base, posed)):
            assert all(math.isfinite(x) for x in b)
            distance = (b-a).length; largest = max(largest, distance)
            if mask.data[i].value == 0.: root_error = max(root_error, distance)
        # Each connected card's horizontal ring is a neighboring vertex pair.
        for i in range(0, len(base), 2):
            width_error = max(width_error, ((posed[i+1]-posed[i])-(base[i+1]-base[i])).length)
    for key, value in [('Wind Enabled', False), ('Wind Strength', 0.)]:
        reset(); set_control(key, value)
        assert error(sample(obj, 9.), base) < 1e-6, (obj.name, key)
    reset()
assert root_error < 1e-7 and width_error < 1e-6, (root_error, width_error)

obj = masters[5]; ui.select(bpy.context, obj['wind_source'])
first = sample(obj, 7.25); sample(obj, 17.); sample(obj, .5)
assert error(first, sample(obj, 7.25)) < 1e-6
loop_error = error(sample(obj, 0.), sample(obj, 20.))
assert loop_error < 3e-6, loop_error
set_control('Wind Speed', 0.)
assert error(sample(obj, 1.), sample(obj, 18.)) < 1e-6
reset()

# Equal times at 30/60 FPS evaluate the same native shape; actual adjacent-frame
# steps around the central gust are bounded, with no dropped/restarted phases.
fps_results = {}; samples = {}
for fps in [30, 60]:
    scene.render.fps = fps
    start = time.perf_counter(); previous = None; maximum_step = 0.; poses = {}
    for frame in range(8 * fps, 10 * fps + 1):
        posed = sample(obj, frame / fps)
        if previous is not None: maximum_step = max(maximum_step, error(posed, previous))
        if frame % (fps // 5) == 0: poses[round(frame / fps, 4)] = posed
        previous = posed
    assert maximum_step < .035, (fps, maximum_step)
    fps_results[str(fps)] = {'max_step_m': maximum_step, 'check_elapsed_s': time.perf_counter()-start}
    samples[fps] = poses
fps_error = max(error(samples[30][t], samples[60][t]) for t in samples[30])
assert fps_error < 2e-6, fps_error
scene.render.fps = 24

# Transform drivers must preserve global wind direction at rotated clumps.
location = obj.location.copy(); rotation = obj.rotation_euler.copy()
obj.location = (0.,0.,1.)
set_control('Per-Clump Variation', 0.)
direction = Vector((math.cos(controller['Wind Direction']), math.sin(controller['Wind Direction']), 0.))
heading_checks = []
for angle in [0., math.pi/2, math.pi, -math.pi/2]:
    obj.rotation_euler.z = angle; obj.update_tag(); bpy.context.view_layer.update()
    posed = sample(obj, 10.); base = rest(obj)
    tips = [i for i in range(len(base)) if obj.data.attributes['md2_wind_t'].data[i].value > .99]
    delta = sum((obj.matrix_world.to_3x3() @ (posed[i]-base[i]) for i in tips), Vector()) / len(tips)
    horizontal = Vector((delta.x, delta.y, 0.)); cosine = horizontal.normalized().dot(direction)
    assert horizontal.length > .05 and cosine > .97, (angle, list(delta), cosine)
    heading_checks.append({'heading_rad':angle,'direction_cosine':cosine})
obj.location = location; obj.rotation_euler = rotation; reset()

# Every individual and field/comparison route is available in the same scene.
routes = ['Field', 'Close', 'Gameplay', 'Compare'] + list(info['individual_visible'])
for key in routes:
    ui.select(bpy.context, key)
    assert bpy.context.view_layer.name == info['layer']
    assert any(a.type == 'VIEW_3D' and a.spaces.active.camera.name == info['cameras'][key] for a in bpy.context.screen.areas)
static_ui.select(bpy.context, 'All')
for key, expected in info['original_timeline'].items(): assert getattr(scene, key) == expected, (key, getattr(scene,key), expected)
for name in ['ViewLayer', 'Short Grass MD2', 'Tall Grass MD2']:
    bpy.context.window.view_layer = scene.view_layers[name]; bpy.context.view_layer.update()
errors = compare(json.loads((E / 'before_native.json').read_text()))
assert not errors, errors
report = {'passed': True, 'original_assets_exact': True, 'native_preservation_errors': errors,
          'root_error_m':root_error,'ring_width_error_m':width_error,'max_default_displacement_sampled_m':largest,
          'default_20s_loop_error_m':loop_error,'fps_30_60_error_m':fps_error,'fps_checks':fps_results,
          'world_heading_checks':heading_checks,'routes_checked':len(routes),'zero_strength_enabled_and_frozen_speed_checked':True,
          'no_cumulative_drift':True,'same_scene':len(bpy.data.scenes)==1,'new_actions':len(bpy.data.actions)}
(E / ('verification_published.json' if target.parent == P else 'verification.json')).write_text(json.dumps(report,indent=2)+'\n')
print('MD2_WIND_VERIFIED', json.dumps(report), flush=True)
