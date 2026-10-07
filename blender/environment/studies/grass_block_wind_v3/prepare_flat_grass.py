"""Full-surface 2D blade revision; Blender asset preparation and demo only."""
import bpy
import math
import random
from pathlib import Path

OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'grass_block_wind_v2'/'grass_block_wind_v2.blend'
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
assert not (OUT/'grass_block_wind_v3.blend').exists()
OUT.mkdir(parents=True,exist_ok=True)
main=bpy.data.scenes['ENV_Grass_Block_Wind_Review']
demo=bpy.data.scenes['ENV_Player_Reaction_Demo']
grass=bpy.data.objects['ENV_Grass_Tuft_Hero']
wind=bpy.data.objects['ENV_Wind_Global']
old_demo=bpy.data.objects['DEMO_Grass_Wind_Plus_Player']
demo_collection=bpy.data.collections['DEMO_ONLY_Player_Reaction']
bpy.data.objects.remove(old_demo,do_unlink=True)
old_controller=bpy.data.objects.get('DEMO_Player_Bend_Controller')
if old_controller: bpy.data.objects.remove(old_controller,do_unlink=True)
material=bpy.data.materials['ENV_Pixel_Atlas_Opaque']
material.use_backface_culling=False

vertices=[];faces=[];blade_info=[];metadata=[];uvs=[]
rng=random.Random(8055)
for row in range(7):
    for col in range(7):
        rootx=-.5+(col+.5)/7+rng.uniform(-.013,.013)
        rooty=-.5+(row+.5)/7+rng.uniform(-.013,.013)
        height=rng.uniform(.245,.38)
        width=rng.uniform(.066,.090)
        angle=(col*2.399+row*1.83+rng.uniform(-.55,.55))%math.pi
        ca,sa=math.cos(angle),math.sin(angle)
        leanx=rng.uniform(-.012,.012)
        leany=rng.uniform(-.012,.012)
        start=len(vertices)
        blade_info.append({'column':col,'row':row,'rootx':rootx,'rooty':rooty,'height':height,'start':start})
        for t in (0,.22,.65,1):
            ww=width*(1 if t<.9 else .73)
            for side in (-1,1):
                vertices.append((rootx+side*ww*.5*ca+leanx*t*t,rooty+side*ww*.5*sa+leany*t*t,height*t))
                metadata.append((t,rootx,rooty,height,col,row))
        for ring in range(3):
            a=start+ring*2
            faces.append((a,a+1,a+3,a+2))
            # Swatches match the original packed atlas, with quiet root/tip tones.
            shade=min(5,(row+col)%3+ring)
            color_uv=((3+(shade+3)*6+.5)/64,(47+.5)/64)
            uvs.append([color_uv]*4)
mesh=bpy.data.meshes.new('ENV_Grass_Full_Surface_2D_Mesh')
mesh.from_pydata(vertices,[],faces)
mesh.update()
mesh.materials.append(material)
uv=mesh.uv_layers.new(name='UV_Atlas')
root_uv=mesh.uv_layers.new(name='UV_Blade_Root')
for polygon,coords in zip(mesh.polygons,uvs):
    polygon.use_smooth=False
    for li,coord in zip(polygon.loop_indices,coords):
        uv.data[li].uv=coord
        vi=mesh.loops[li].vertex_index
        _,rx,ry,_,_,_=metadata[vi]
        root_uv.data[li].uv=(rx+.5,ry+.5)
mesh.uv_layers.active_index=0
uv.active_render=True
root_uv.active_render=False
grass.data=mesh
grass.name='ENV_Grass_Full_Surface_2D'
grass.vertex_groups.clear()
group=grass.vertex_groups.new(name='WIND_HEIGHT_SQUARED')
data=mesh.color_attributes.new(name='GRASS_BEND_DATA',type='FLOAT_COLOR',domain='POINT')
for i,(t,rx,ry,h,col,row) in enumerate(metadata):
    group.add([i],t*t,'REPLACE')
    data.data[i].color=(t*t,t,h/.38,1)
mesh.color_attributes.active_color=data
mesh.color_attributes.render_color_index=mesh.color_attributes.find(data.name)
grass.shape_key_add(name='Basis',from_mix=False)
for axis,trig in (('X','Sin'),('X','Cos'),('Y','Sin'),('Y','Cos')):
    key=grass.shape_key_add(name='Wind_'+axis+'_'+trig,from_mix=False)
    key.slider_min=-1;key.slider_max=1
    for i,(t,rx,ry,h,col,row) in enumerate(metadata):
        lag=-.28*t if axis=='X' else math.pi/3-.23*t
        amount=(.018 if axis=='X' else .007)*t*t
        key.data[i].co[0 if axis=='X' else 1]+=amount*(math.cos(lag) if trig=='Sin' else math.sin(lag))
    driver=key.driver_add('value').driver
    variable=driver.variables.new();variable.name='p';variable.type='SINGLE_PROP'
    variable.targets[0].id=wind;variable.targets[0].data_path='["phase"]'
    driver.expression='sin(p)' if trig=='Sin' else 'cos(p)'
for axis in ('X','Y'):
    key=grass.shape_key_add(name='Player_Bend_'+axis,from_mix=False)
    key.slider_min=-2;key.slider_max=2
    for i,info in enumerate(metadata):
        key.data[i].co[0 if axis=='X' else 1]+=.1*info[0]**2
    key.value=0
grass.data.shape_keys.name='ENV_Flat_Grass_Wind_Player_Prepared'
grass['blade_count']=49
grass['blade_geometry']='49 flat 2D strips, 4 height rings each, two-sided opaque shading, no thickness.'
grass['coverage']='Even 7x7 root grid across the full 1m top, small jitter and varied angles for moderate interweaving.'
grass['deform_attribute']='GRASS_BEND_DATA: R=t^2, G=t, B=blade height/0.38m, A=1.'
grass['root_uv_attribute']='UV_Blade_Root / UV2: root local XY encoded as (x+0.5,y+0.5). Decode and transform to world for per-blade proximity.'
grass['future_player_ready']=True
grass['wind_loop_seconds']=4
grass['wind_tip_amplitude_x_m']=.018
grass['wind_tip_amplitude_y_m']=.007
grass['origin_note']='Local root plane Z=0; patch placed at world Z=1.'
grass['player_effect_default']='Prepared Player_Bend_X/Y remain zero in the wind-only main scene.'

# A separate preview copy demonstrates localized disturbance of the flat leaves.
demograss=grass.copy();demograss.data=grass.data.copy()
demograss.name='DEMO_Grass_Wind_Plus_Player'
demograss.data.name='DEMO_Flat_Grass_Mesh'
demograss['demo_only']=True
demo_collection.objects.link(demograss)
assert demograss.data.shape_keys!=grass.data.shape_keys
def smoothstep(x):
    x=max(0,min(1,x));return x*x*(3-2*x)
for column in range(7):
    rootx=-.5+(column+.5)/7
    walk_center=1+(rootx+.92)/.023
    run_center=105+(.92-rootx)/.0575
    walk_profile=[(-22,0),(-12,.13),(-6,.36),(2,.52),(10,.47),(20,.24),(28,.07),(36,-.055),(48,0)]
    run_profile=[(-11,0),(-5,-.48),(0,-.94),(6,-.83),(16,-.38),(28,.10),(48,0)]
    for axis in ('X','Y'):
        key=demograss.shape_key_add(name=f'DEMO_Player_Column_{column}_{axis}',from_mix=False)
        key.slider_min=-2;key.slider_max=2
        for i,(t,rx,ry,h,col,row) in enumerate(metadata):
            if col!=column:continue
            lateral=smoothstep(1-abs(ry+.06)/.30)
            away_sign=1 if ry>=-.06 else -1
            key.data[i].co[0 if axis=='X' else 1]+=.1*t*t*lateral*(1 if axis=='X' else away_sign)
        for frame,value in [(1,0)]+[(walk_center+dt,v) for dt,v in walk_profile]+[(97,0)]+[(run_center+dt,v) for dt,v in run_profile]+[(193,0)]:
            frame=max(1,min(193,frame))
            key.value=value if axis=='X' else abs(value)*.23
            key.keyframe_insert(data_path='value',frame=frame)
        key.value=0
action=demograss.data.shape_keys.animation_data.action
action.name='DEMO_Local_2D_Grass_Walk_Run_Return'
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation='BEZIER'
                    point.handle_left_type='AUTO_CLAMPED'
                    point.handle_right_type='AUTO_CLAMPED'
demograss['demo_method']='Seven authored column responses: bend near the Player path, remain wind-only beyond 0.30m from the path, recover with a small rebound. No simulation.'
demo['review_note']='Walking right then running left through full-surface 2D grass. Local blade columns respond near the blue Player proxy; outer rows keep only wind. Authored illustrative curves, no runtime interaction.'
main['player_demo_scene']='ENV_Player_Reaction_Demo'
main['review_hint']='2D leaves cover the full block. Main scene: wind 1-96. Scene menu -> ENV_Player_Reaction_Demo: walk/run reaction 1-192.'
for marker in list(demo.timeline_markers): demo.timeline_markers.remove(marker)
for frame,name in ((1,'WALK_APPROACH'),(41,'WALK_PASS'),(103,'WALK_RECOVERED'),(105,'RUN_APPROACH'),(121,'RUN_PASS'),(185,'RUN_RECOVERED'),(193,'GRASS_SEAM_MATCH')):
    demo.timeline_markers.new(name,frame=frame)
demo.frame_set(1);main.frame_set(1)
if bpy.context.window:bpy.context.window.scene=main
for obj in main.objects: obj.select_set(False)
grass.select_set(True)
bpy.context.view_layer.objects.active=grass
main.render.filepath=str(OUT/'preview_hero.png')
image=bpy.data.images['ENV_Atlas_64_Nearest']
(OUT/'environment_atlas_64.png').write_bytes(bytes(image.packed_file.data))
image.filepath='//environment_atlas_64.png'
old_notes=bpy.data.texts['REVIEW_NOTES'].as_string()
notes='''FULL-SURFACE 2D GRASS | BLENDER REVIEW v3

Latest direction: flat leaves evenly spread across the whole block surface, moderately
interwoven. 49 leaves on a jittered 7x7 root grid, varied angles/heights, no thickness.
Four height rings per leaf (0, 0.22, 0.65, 1); only 294 triangles for the complete patch.
Two-sided opaque material: no alpha overdraw, bevels, physics or subdivision.
The exact 1 x 1 x 1 block is unchanged. Grass roots are local Z=0, placed at world Z=1.

GPU PREPARATION:
GRASS_BEND_DATA (POINT/FLOAT_COLOR): R=t^2, G=t, B=blade height/0.38m, A=1.
UV_Blade_Root (second UV map / UV2): each blade's root XY encoded as (x+0.5,y+0.5).
Decode root XY by subtracting 0.5 and transform the root to world space for proximity.
This lets a full patch respond per blade, including leaving distant blades unaffected.
The mask is deformation data, not albedo: the pixel material ignores vertex colors.
Roots have R=G=0 exactly. Upper rings bend more. Both wind and disturbance use this mask.

MAIN SCENE: ENV_Grass_Block_Wind_Review, wind only, 1-96 at 24fps, 4 seconds.
Global phase = 2*pi*(frame-1)/96. Tip amplitude 1.8cm X, 0.7cm Y with small height delay.
Player_Bend_X/Y are prepared and zero. Frame 97 is the duplicate seam, excluded.

DEMO SCENE: ENV_Player_Reaction_Demo, 1-192 at 24fps, 8 seconds.
The blue marker walks right at 0.552m/s, then runs left at 1.38m/s.
Seven authored response columns demonstrate localized bending near the path.
Blades beyond 0.30m sideways from the Player path receive no Player displacement.
Walking is gentle, running is stronger/faster; both follow through and rebound softly.
Global wind continues throughout. Bases stay fixed. This is a short authored visual
demonstration, not a proximity-query implementation or a physics simulation.

FUTURE GODOT SUPPORT (DOCUMENTATION ONLY):
Final displacement = shared global wind + local Player disturbance, multiplied by
the per-vertex bend mask. Only the Player supplies global position, movement/speed,
and a short fixed history of movement segments with timestamps (e.g. 4 segments).
A shared GPU vertex shader uses per-blade world root distance to those segments,
smoothstep radius falloff, outward direction plus a small movement-direction push,
speed-dependent strength/response, and a smooth time envelope for follow-through
and recovery. Current position alone is insufficient for recovery after departure.
Use continuous envelopes at influence/age boundaries and clamp the total bend.
All instances use one global wind phase/direction; optional seeded amplitude variation
can be small. No independent clocks, per-grass physics, scripts or AnimationPlayers.
Ignore enemies. Convert Blender Z to the future engine's up axis. The mask is
axis-independent; convert world wind vectors to each instance's local coordinates.

REVIEW: density, coverage, flat-leaf silhouette, scale, colors, wind strength,
and walk/run bend/recovery. No Godot files or runtime systems were created.
'''
bpy.data.texts['REVIEW_NOTES'].clear();bpy.data.texts['REVIEW_NOTES'].write(notes)
(OUT/'REVIEW_NOTES.txt').write_text(notes,encoding='utf-8')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'grass_block_wind_v3.blend'))
bpy.ops.render.render(write_still=True)
print('FULL_SURFACE_2D_GRASS_READY')
