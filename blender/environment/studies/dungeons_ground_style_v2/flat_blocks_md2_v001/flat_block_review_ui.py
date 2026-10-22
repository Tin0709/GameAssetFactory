"""Soft-textured blocks in the same Grass MD2 environment-library sidebar."""
import bpy, json

def record(context):
    return json.loads(context.scene.get('md2_flat_blocks_review', '{}'))

def select(context, key='All'):
    info = record(context)
    if not info or key not in info['cameras']:
        raise ValueError('Unknown flat-block view: ' + key)
    if 'md2_interaction_review' in context.scene:
        import interaction_review_ui
        interaction_review_ui.leave(context)
    if 'md2_wind_review' in context.scene:
        import wind_review_ui
        wind_review_ui.leave(context)
    layer = context.scene.view_layers[info['layer']]
    context.window.view_layer = layer
    for name, obj_name in info['objects'].items():
        bpy.data.objects[obj_name].hide_set(key not in ('All','Opposite',name), view_layer=layer)
    for area in context.screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.use_local_camera = True
            space.camera = bpy.data.objects[info['cameras'][key]]
            space.region_3d.view_perspective = 'CAMERA'
            space.region_3d.view_camera_zoom = 0
            space.show_region_ui = True
            space.overlay.show_overlays = False
            area.tag_redraw()
    context.scene['md2_flat_blocks_selected'] = key

class MD2_OT_flat_block_view(bpy.types.Operator):
    bl_idname = 'md2_flat_blocks.view'
    bl_label = 'View flat block'
    key: bpy.props.StringProperty(default='All')
    def execute(self, context):
        select(context, self.key)
        return {'FINISHED'}

class MD2_PT_flat_blocks(bpy.types.Panel):
    bl_label = 'Blocks MD2 — Soft Texture'
    bl_idname = 'MD2_PT_flat_blocks'
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Grass MD2'
    bl_order = -30
    @classmethod
    def poll(cls, context):
        return 'md2_flat_blocks_review' in context.scene
    def draw(self, context):
        layout = self.layout
        layout.operator('md2_flat_blocks.view', text='ALL 3 BLOCKS', icon='MESH_CUBE').key = 'All'
        row = layout.row(align=True)
        for key in ('Grass','Dirt','Stone'):
            row.operator('md2_flat_blocks.view', text=key).key = key
        layout.operator('md2_flat_blocks.view', text='Opposite view').key = 'Opposite'
        key = context.scene.get('md2_flat_blocks_selected', 'All')
        info = record(context)
        if key in info['objects']:
            layout.label(text=bpy.data.objects[info['objects'][key]]['flat_color_hex'])
        layout.label(text='Grass cap over dirt · subtle pixels')
        layout.label(text='1 × 1 × 1 block · matte')
        layout.label(text='Pending · Blender review only', icon='INFO')

def register():
    for cls in (MD2_OT_flat_block_view, MD2_PT_flat_blocks):
        if not hasattr(bpy.types, cls.__name__):
            bpy.utils.register_class(cls)
