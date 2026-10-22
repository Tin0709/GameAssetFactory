"""Reopen the saved library, verify additive preservation and render actual blocks."""
import bpy, json, sys
from pathlib import Path

D=Path(__file__).resolve().parent;P=D.parent;R=P.parents[3];E=R/'.validation/flat_blocks_v001'
sys.path[:0]=[str(P),str(P/'tall_grass_md2_v001')]
from flower_preservation import compare
bpy.ops.wm.open_mainfile(filepath=str(P/'dungeons_ground_style_v2.blend'))
scene=bpy.context.scene
changes=compare(json.loads((E/'native_before.json').read_text()))
assert not changes,changes
import grass_library_ui as ui
ui.register()
import flat_block_review_ui as flat
info=flat.record(bpy.context)
checks=[]
for key in ['All','Grass','Dirt','Stone','Opposite','All']:
    assert bpy.ops.md2_flat_blocks.view(key=key)=={'FINISHED'}
    bpy.context.view_layer.update()
    assert bpy.context.view_layer.name==info['layer']
    shown={k for k,n in info['objects'].items() if not bpy.data.objects[n].hide_get()}
    assert shown==({'Grass','Dirt','Stone'} if key in ['All','Opposite'] else {key}),shown
    checks.append(key)
# Old controls are still reachable; return to the new set without saving transient UI.
for key in ['All','S:Overview','T:Overview','TC:Soft Meadow']:
    ui.select(bpy.context,key);checks.append(key)
import wind_review_ui, interaction_review_ui
wind_review_ui.select(bpy.context,'Field');checks.append('Wind')
interaction_review_ui.select(bpy.context);checks.append('Interaction')
flat.select(bpy.context,'All')
palette=json.loads((D/'palette.json').read_text())
for key,name in info['objects'].items():
    obj=bpy.data.objects[name];obj.data.calc_loop_triangles()
    assert tuple(obj.dimensions)==(1.,1.,1.) and len(obj.data.loop_triangles)==12
    assert len(obj.data.materials)==1 and not obj.modifiers
    assert obj['flat_color_hex']==palette['blocks'][key]['hex']
    assert not any(n.type=='TEX_IMAGE' for n in obj.active_material.node_tree.nodes)
    assert obj.asset_data and obj.asset_data.catalog_id==info['catalog']
    for polygon in obj.data.polygons:
        assert polygon.material_index==0 and not polygon.use_smooth
# Render a temporary copy: no original scene camera, world, color or render settings saved.
preview=scene.copy();preview.name='TEMP_Flat_Block_Preview'
for layer in list(preview.view_layers):
    if layer.name!=info['layer']:preview.view_layers.remove(layer)
preview.camera=bpy.data.objects[info['cameras']['All']]
preview.render.engine='CYCLES';preview.cycles.samples=32;preview.cycles.use_denoising=True
preview.render.resolution_x=1440;preview.render.resolution_y=800;preview.render.resolution_percentage=100
preview.render.image_settings.file_format='PNG'
preview.view_settings.view_transform='Standard';preview.view_settings.look='None'
preview.view_settings.exposure=0.;preview.view_settings.gamma=1.
preview.world=bpy.data.worlds.new('TEMP_Flat_Block_Neutral_World');preview.world.use_nodes=True
preview.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.7,.7,.7,1.)
preview.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
preview.render.filepath=str(D/'preview.png')
bpy.ops.render.render(scene=preview.name,write_still=True)
report={'native_preservation_changes':changes,'routes':checks,'blocks':list(info['objects']),
    'dimensions_m':[1,1,1],'triangles_each':12,'materials_each':1,'texture_nodes':0,'saved_and_reopened':True,'status':'Pending'}
(E/'verification.json').write_text(json.dumps(report,indent=2))
print('MD2_FLAT_BLOCKS_VERIFIED',json.dumps(report),flush=True)
