"""Prepare the v1 geometry for GPU bending and author a small Blender-only demo."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'grass_block_wind_v1'/'grass_block_wind_v1.blend'
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
assert not (OUT/'grass_block_wind_v2.blend').exists()
OUT.mkdir(parents=True,exist_ok=True)
main=bpy.context.scene
main.name='ENV_Grass_Block_Wind_Review'
grass=bpy.data.objects['ENV_Grass_Tuft_Hero']
block=bpy.data.objects['ENV_GrassDirt_Block_1m']
wind=bpy.data.objects['ENV_Wind_Global']

# A GPU-readable color attribute: no shader/runtime is created in this study.
data=grass.data.color_attributes.new(name='GRASS_BEND_DATA',type='FLOAT_COLOR',domain='POINT')
mask=grass.vertex_groups['WIND_HEIGHT_SQUARED']
for vertex in grass.data.vertices:
    weight=mask.weight(vertex.index)
    t=weight**.5
    blade=vertex.index//16
    # Each blade's final ring stores its undeformed height.
    height=grass.data.shape_keys.key_blocks['Basis'].data[blade*16+12].co.z
    data.data[vertex.index].color=(weight,t,height/.44,1)
grass.data.color_attributes.active_color=data
grass.data.color_attributes.render_color_index=grass.data.color_attributes.find(data.name)
grass['deform_attribute']='GRASS_BEND_DATA: R=height^2, G=normalized blade height, B=blade height/0.44, A=1'
grass['future_player_ready']=True
grass['player_effect_default']='Disabled in hero review. Separate demo scene combines it with wind.'
for axis in ('X','Y'):
    key=grass.shape_key_add(name='Player_Bend_'+axis,from_mix=False)
    key.slider_min=-2
    key.slider_max=2
    for v in grass.data.vertices:
        key.data[v.index].co[0 if axis=='X' else 1]+=.1*mask.weight(v.index)
    key.value=0

demo=bpy.data.scenes.new('ENV_Player_Reaction_Demo')
demo.world=main.world
demo.render.engine=main.render.engine
demo.render.resolution_x=800
demo.render.resolution_y=800
demo.render.resolution_percentage=100
demo.render.fps=24
demo.frame_start=1
demo.frame_end=192
demo.view_settings.view_transform=main.view_settings.view_transform
demo.view_settings.look=main.view_settings.look
demo.unit_settings.system='METRIC'
demo.unit_settings.scale_length=1
demo.render.image_settings.file_format='PNG'
studio=bpy.data.collections['03_REVIEW_STUDIO']
demo.collection.children.link(studio)
demo.collection.objects.link(block)
demo.collection.objects.link(wind)
demo_assets=bpy.data.collections.new('DEMO_ONLY_Player_Reaction')
demo.collection.children.link(demo_assets)
demo_grass=grass.copy()
demo_grass.data=grass.data.copy()
demo_grass.name='DEMO_Grass_Wind_Plus_Player'
demo_grass.data.name='DEMO_Grass_Wind_Plus_Player_Mesh'
demo_assets.objects.link(demo_grass)
assert demo_grass.data.shape_keys!=grass.data.shape_keys
demo_grass['demo_only']=True
demo_grass['note']='Same prepared topology and masks as hero; demonstration copy, not a second production asset.'
controller=bpy.data.objects.new('DEMO_Player_Bend_Controller',None)
demo_assets.objects.link(controller)
controller['bend_x']=0.0
controller['bend_y']=0.0
controller['demo_method']='Authored curves illustrating proximity, follow-through, and rebound; no physics simulation.'
walk=[(1,0),(19,0),(29,.13),(35,.36),(43,.52),(51,.47),(61,.24),(69,.07),(77,-.055),(89,0),(97,0)]
run=[(105,0),(110,0),(116,-.48),(121,-.94),(127,-.83),(137,-.38),(149,.10),(169,0),(193,0)]
for frame,value in walk+run:
    controller['bend_x']=value
    controller['bend_y']=abs(value)*.23
    controller.keyframe_insert(data_path='["bend_x"]',frame=frame)
    controller.keyframe_insert(data_path='["bend_y"]',frame=frame)
for slot in controller.animation_data.action.layers:
    for strip in slot.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation='BEZIER'
                    point.handle_left_type='AUTO_CLAMPED'
                    point.handle_right_type='AUTO_CLAMPED'
controller.animation_data.action.name='DEMO_Walk_Run_Soft_Return'
for axis in ('X','Y'):
    key=demo_grass.data.shape_keys.key_blocks['Player_Bend_'+axis]
    driver=key.driver_add('value').driver
    variable=driver.variables.new()
    variable.name='bend'
    variable.type='SINGLE_PROP'
    variable.targets[0].id=controller
    variable.targets[0].data_path='["bend_'+axis.lower()+'"]'
    driver.expression='bend'

proxy_mat=bpy.data.materials.new('DEMO_Player_Proxy_Blue')
proxy_mat.use_nodes=True
proxy_mat.diffuse_color=(.12,.4,.5,1)
proxy_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.12,.4,.5,1)
proxy_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
verts=[(x,y,z) for z in (0,.54) for y in (-.055,.055) for x in (-.055,.055)]
faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
mesh=bpy.data.meshes.new('DEMO_Player_Proxy_Mesh')
mesh.from_pydata(verts,[],faces)
mesh.materials.append(proxy_mat)
proxy=bpy.data.objects.new('DEMO_Player_Proxy',mesh)
demo_assets.objects.link(proxy)
proxy['role']='Player movement marker only; not a character asset or enemy interaction.'
proxy['walk_speed_m_per_second']=.552
proxy['run_speed_m_per_second']=1.38
proxy['illustrated_influence_radius_m']=.48
for frame,x in ((1,-.92),(81,.92),(105,.92),(137,-.92),(193,-.92)):
    proxy.location=(x,-.06,1)
    proxy.keyframe_insert(data_path='location',frame=frame)
for layer in proxy.animation_data.action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation='LINEAR'
proxy.animation_data.action.name='DEMO_Player_Walk_Then_Run'
demo.camera=bpy.data.objects['REVIEW_Camera_Hero']
for frame,name in ((1,'WALK_APPROACH'),(41,'WALK_PASS'),(89,'WALK_RECOVERED'),(105,'RUN_APPROACH'),(121,'RUN_PASS'),(169,'RUN_RECOVERED'),(193,'GRASS_SEAM_MATCH')):
    demo.timeline_markers.new(name,frame=frame)
demo['review_note']='8-second Blender-only illustration: walking right, running left, both combined with global wind. Authored proximity-response curves, not a runtime interaction system.'
demo['future_interaction']='Only the Player publishes position, movement, speed and short trail history. No enemies or per-grass physics/scripts.'
main['future_player_interaction_ready']=True
main['player_demo_scene']='ENV_Player_Reaction_Demo'
main.frame_set(1)
demo.frame_set(1)
if bpy.context.window:
    bpy.context.window.scene=main
main.render.filepath=str(OUT/'preview_hero.png')
main['review_hint']='Main scene: wind 1-96. Scene menu -> ENV_Player_Reaction_Demo: walk/run interaction 1-192. Space plays. Read REVIEW_NOTES.'

notes='''PLAYER-REACTIVE GRASS PREPARATION | BLENDER REVIEW v2

Original exact 1m block and 14-blade tuft preserved. Four height rings per blade
(0, 0.22, 0.65, 1), 392 grass triangles, no subdivisions, no physics.
Root vertices stay fixed. Upper vertices bend more strongly with height squared.
One GPU-readable POINT/FLOAT_COLOR attribute: GRASS_BEND_DATA.
R = t squared (bend mask), G = t (per-blade normalized height),
B = blade height / 0.44m, A = 1. This mask is deformation data, not surface color.
The current pixel material ignores it; a future custom GPU shader can read it.
Do not multiply the atlas by this vertex color in the future grass shader.

WIND REVIEW: ENV_Grass_Block_Wind_Review, 1-96 at 24fps, 4 seconds.
One global phase, fixed roots, 1.8cm X / 0.7cm Y tip amplitude, slight height delay.
Two prepared Player_Bend_X/Y shape keys stay zero in this hero scene.

PLAYER DEMO: scene menu -> ENV_Player_Reaction_Demo, 1-192 at 24fps.
Space plays. The blue cuboid is only a Player movement proxy.
It walks right at 0.552m/s, then runs left at 1.38m/s.
Walking bends tips about 5cm; running bends about 9.6cm and responds sooner.
Both recover softly with a small authored rebound. Wind continues underneath.
The demonstration copy uses the same topology and masks as the hero.
This is an authored illustration of a local pass and recovery, not a simulation
or a distance-query runtime. No enemies affect the grass. The original v1 is safe.

FUTURE GODOT RECOMMENDATION ONLY:
Final vertex displacement = shared global wind + local Player disturbance.
Only one Player-side provider publishes world position, velocity/direction/speed,
and a short fixed-size history of recent movement segments with timestamps.
Use global shader uniforms and one shared grass shader; do not create per-patch
scripts, physics bodies, or AnimationPlayers for thousands of patches.
Evaluate squared distance from each grass root to the current or recent Player
movement segments. Smoothstep falloff goes to zero outside a small radius.
Combine radial push-away direction with a smaller motion-direction component.
Walking uses a smaller amplitude and slower response; running a larger, quicker one.
For follow-through and recovery in a stateless vertex shader, evaluate a smooth
time envelope or damped response from the recent timestamped segments. Current
position alone cannot describe which patches were recently disturbed after departure.
Keep a short fixed trail (e.g. 4 recent segments), prune expired samples in the single
Player provider, and cap total offset. Mask both wind and disturbance by R=t^2,
with root mask exactly zero. G supports a small height-dependent response delay.
Use continuous envelopes with zero influence at radius/age boundaries to avoid snapping.
Use the same global wind phase across every instance. Optional seeded amplitude
variation is okay; use no independent clocks. Convert wind/displacement between
world and local coordinates so rotated instances keep one coherent world direction.
Godot's up axis requires coordinate conversion from Blender Z; mask is axis-independent.
No Godot files, shaders, export assets or runtime systems were created in this task.

REVIEW: art palette, tuft scale/density, wind subtlety, and walk/run bend and rebound.
The prepared four-ring silhouette is intentionally stylized; assess it at gameplay
distance. A denser mesh or per-grass physics is not needed for this small bend.
'''
bpy.data.texts['REVIEW_NOTES'].clear()
bpy.data.texts['REVIEW_NOTES'].write(notes)
(OUT/'REVIEW_NOTES.txt').write_text(notes,encoding='utf-8')
image=bpy.data.images['ENV_Atlas_64_Nearest']
# Extract the existing packed atlas; no texture/color changes in this revision.
(OUT/'environment_atlas_64.png').write_bytes(bytes(image.packed_file.data))
image.filepath='//environment_atlas_64.png'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'grass_block_wind_v2.blend'))
bpy.ops.render.render(write_still=True)
print('PLAYER_REACTIVE_STUDY_READY')
