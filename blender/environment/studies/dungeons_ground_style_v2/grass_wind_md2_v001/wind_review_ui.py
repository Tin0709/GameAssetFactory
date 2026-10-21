"""Wind controls and views, registered by the existing environment viewer."""
import json
import bpy
from pathlib import Path
from mathutils import Vector

LIB = 'dungeons_ground_style_v2.blend'

def record():
    return json.loads(bpy.context.scene.get('md2_wind_review', '{}'))

def leave(context):
    scene = context.scene
    if not scene.get('md2_wind_view_active'): return
    info = record()
    if context.screen.is_animation_playing:
        bpy.ops.screen.animation_cancel(restore_frame=False)
    original = json.loads(scene.get('md2_wind_return_timeline', json.dumps(info['original_timeline'])))
    scene.use_preview_range = False
    scene.frame_start = original['frame_start']; scene.frame_end = original['frame_end']
    scene.frame_preview_start = original['frame_preview_start']; scene.frame_preview_end = original['frame_preview_end']
    scene.use_preview_range = original['use_preview_range']
    if 'sync_mode' in original: scene.sync_mode = original['sync_mode']
    scene.frame_set(original['frame_current'])
    scene['md2_wind_view_active'] = False

def select(context, key):
    scene = context.scene; info = record()
    assert Path(bpy.data.filepath).name == LIB and info
    layer = scene.view_layers[info['layer']]; context.window.view_layer = layer
    visible = {o.name for o in bpy.data.collections[info['studio_collection']].all_objects}
    if key in ['Field', 'Close', 'Gameplay']:
        visible.update(o.name for o in bpy.data.collections[info['field_collection']].all_objects)
    elif key == 'Compare':
        visible.update(o.name for o in bpy.data.collections[info['compare_collection']].all_objects)
    else:
        visible.update(info['individual_visible'][key])
    # Visibility changes invalidate Blender's live all_objects iterator.
    for obj in list(bpy.data.collections[info['root']].all_objects):
        obj.hide_set(obj.name not in visible, view_layer=layer)
        obj.hide_render = obj.name not in visible
    # Keep the same review illumination on the distant individual/compare rows.
    target = Vector((13.,4.8,1.)) if key == 'Compare' else Vector((0.,0.,1.))
    if key in info['individual_visible']:
        target.x = bpy.data.objects[info['individual_visible'][key][0]].location.x
    for name, offset in [('MD2_Wind_Key',(0.,-4.,9.)), ('MD2_Wind_Fill',(5.,4.,6.))]:
        light = bpy.data.objects[name]; light.location = target + Vector(offset)
        light.rotation_euler = (target-light.location).to_track_quat('-Z','Y').to_euler()
    for area in context.screen.areas:
        if area.type == 'VIEW_3D':
            view = area.spaces.active; view.use_local_camera = True
            view.camera = bpy.data.objects[info['cameras'][key]]
            view.region_3d.view_perspective = 'CAMERA'; view.region_3d.view_camera_zoom = 0.
            view.overlay.show_overlays = False; view.show_region_ui = True; area.tag_redraw()
    if not scene.get('md2_wind_view_active'):
        scene['md2_wind_return_timeline'] = json.dumps({k: getattr(scene,k) for k in set(info['original_timeline']) | {'sync_mode'}})
        scene.use_preview_range = False
        scene.frame_start = 1
        scene.frame_end = max(scene.frame_end, round(info['duration_s'] * scene.render.fps / scene.render.fps_base))
        scene.frame_preview_start = 1
        scene.frame_preview_end = round(info['duration_s'] * scene.render.fps / scene.render.fps_base)
        scene.use_preview_range = True; scene.frame_set(1)
    scene.sync_mode = 'FRAME_DROP'
    scene['md2_wind_view_active'] = True; scene['md2_wind_selected'] = key
    context.view_layer.update()

class MD2_OT_wind_view(bpy.types.Operator):
    bl_idname = 'md2_wind.view'; bl_label = 'Grass wind review'
    key: bpy.props.StringProperty()
    def execute(self, context):
        select(context, self.key); return {'FINISHED'}

class MD2_OT_wind_play(bpy.types.Operator):
    bl_idname = 'md2_wind.play'; bl_label = 'Play / pause wind at original speed'
    reset: bpy.props.BoolProperty(default=False)
    def execute(self, context):
        if not context.scene.get('md2_wind_view_active'): select(context, 'Field')
        if self.reset:
            if context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
            context.scene.frame_set(1)
        else:
            bpy.ops.screen.animation_play()
        return {'FINISHED'}

class MD2_PT_wind(bpy.types.Panel):
    bl_label = 'Grass MD2 — Wind · Pending'; bl_idname = 'MD2_PT_wind'
    bl_space_type = 'VIEW_3D'; bl_region_type = 'UI'; bl_category = 'Grass MD2'; bl_order = -20
    @classmethod
    def poll(cls, context):
        return Path(bpy.data.filepath).name == LIB and 'md2_wind_review' in context.scene
    def draw(self, context):
        info = record(); layout = self.layout
        row = layout.row(align=True)
        for key, title in [('Field', 'Mixed field'), ('Close', 'Close-up')]:
            row.operator('md2_wind.view', text=title).key = key
        row = layout.row(align=True)
        for key, title in [('Gameplay', 'Gameplay'), ('Compare', 'Static / Wind')]:
            row.operator('md2_wind.view', text=title).key = key
        row = layout.row(align=True)
        row.operator('md2_wind.play', text='Play / Pause · 1×', icon='PLAY')
        row.operator('md2_wind.play', text='Restart', icon='REW').reset = True
        controller = bpy.data.objects[info['controller']]
        for name in ['Wind Enabled', 'Wind Direction', 'Wind Strength', 'Wind Speed', 'Gust Strength', 'Gust Frequency', 'Per-Clump Variation', 'Short Grass Response', 'Tall Grass Response']:
            layout.prop(controller, '["' + name + '"]', text=name)
        layout.label(text='20 seconds · shared moving gust')
        layout.label(text='Pending · Blender review only', icon='INFO')

class MD2_PT_wind_individual(bpy.types.Panel):
    bl_label = 'Individual Short / Tall Wind'; bl_idname = 'MD2_PT_wind_individual'
    bl_parent_id = 'MD2_PT_wind'; bl_space_type = 'VIEW_3D'; bl_region_type = 'UI'
    bl_category = 'Grass MD2'; bl_options = {'DEFAULT_CLOSED'}
    def draw(self, context):
        layout = self.layout; info = record()
        for key, title in [('md2_review', 'SHORT · 0.5 block'), ('md2_tall_review', 'TALL · fanned seed tips')]:
            layout.label(text=title)
            names = json.loads(context.scene[key])['masters']
            for index, name in enumerate(names):
                obj = bpy.data.objects[name]
                variant = obj.get('variant', 'Dense Cluster')
                text = chr(65+index) + ' · ' + variant if index < 4 else variant
                layout.operator('md2_wind.view', text=text, icon='MESH_DATA').key = name

def register():
    for cls in [MD2_OT_wind_view, MD2_OT_wind_play, MD2_PT_wind, MD2_PT_wind_individual]:
        if not hasattr(bpy.types, cls.__name__): bpy.utils.register_class(cls)

def start_preview():
    if bpy.app.background or not record() or not bpy.context.scene.get('md2_wind_view_active'): return
    if not bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
