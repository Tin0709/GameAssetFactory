"""Shared zombie mesh/action, distinct deterministic NLA phase/rate offsets."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'zombie_animation_v2.blend'))
scene=bpy.context.scene
original=bpy.data.objects['Zombie_Cuboid_Rig'];mesh=bpy.data.objects['Zombie_Cuboid_Base'];action=bpy.data.actions['Zombie_Walk']
settings=[(-1.7,.00,.00,.97),(-.85,.15,.19,1.03),(0,0,.43,1.00),(.85,.15,.67,.95),(1.7,0,.84,1.05)]
rows=[]
for i,(x,y,phase,rate) in enumerate(settings):
    rig=original if i==0 else original.copy()
    character=mesh if i==0 else mesh.copy()
    if i:
        scene.collection.objects.link(rig);scene.collection.objects.link(character)
        character.parent=rig
        for mod in character.modifiers:
            if mod.type=='ARMATURE':mod.object=rig
    rig.name=f'Crowd_Zombie_{i}';rig.location=(x,y,0)
    rig.animation_data_clear();rig.animation_data_create()
    track=rig.animation_data.nla_tracks.new();track.name='Shared walk / spawn variation'
    strip=track.strips.new('Spawn phase',-100,action)
    strip.action_frame_start=1;strip.action_frame_end=49;strip.scale=1/rate
    strip.repeat=20;strip.frame_start=1-phase*48/rate
    strip.blend_type='REPLACE'
    rig['spawn_phase']=phase;rig['gait_rate']=rate
    rows.append({'entity':i,'phase':phase,'rate':rate})
scene.camera.location=(-3.4,-8,4.0)
scene.camera.rotation_euler=(Vector((0,0,.9))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=5.4
scene.render.resolution_x=960;scene.render.resolution_y=540
scene.frame_start=1;scene.frame_end=144;scene.frame_set(12)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'zombie_crowd_review.blend'))
scene.render.filepath=str(OUT/'zombie_crowd_review.png');bpy.ops.render.render(write_still=True)
(OUT/'zombie_variation.json').write_text(json.dumps(rows,indent=2))
print('CROWD_REVIEW_SUCCESS')
