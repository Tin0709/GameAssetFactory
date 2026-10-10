"""Add the requested flat-ground jump to the live library; never rebuild old actors.

Run through the connected Blender session after preserving its unsaved state.
Animation edits are isolated to JD1 objects and two new, single-slot Actions.
"""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector, Euler, Matrix

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
SCENE = 'JUMP_DEFAULT_V001_REVIEW'
POSE = 'Jump_Default_v001'
TRAVEL = 'PREVIEW_ONLY_Jump_Default_v001_Travel'

def curves(action):
    return [c for l in action.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]

def signature(action):
    return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(action)]).encode()).hexdigest()

def camera(scene, name, location, target, scale):
    data=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,data)
    scene.collection.objects.link(ob); ob.location=location
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO'; data.ortho_scale=scale; data.lens=50
    return ob

def build():
    if bpy.context.screen.is_animation_playing:
        bpy.ops.screen.animation_cancel(restore_frame=False)
    assert bpy.context.mode=='OBJECT'
    assert not bpy.data.scenes.get(SCENE), 'Do not overwrite an existing review'
    assert not bpy.data.actions.get(POSE)
    library=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1']
    info=json.loads(library['review_actors'])['Hold_Unarmed']
    source=bpy.data.objects[info['rig']]
    body=next(o for o in source.children_recursive if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
    baseline={a.name:signature(a) for a in bpy.data.actions}
    scene=bpy.data.scenes.new(SCENE)
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.render.resolution_x=960; scene.render.resolution_y=900; scene.render.resolution_percentage=100
    scene.render.fps=30; scene.render.fps_base=1; scene.frame_start=1; scene.frame_end=25
    scene.render.film_transparent=False; scene.render.image_settings.file_format='PNG'
    scene.render.use_file_extension=True; scene.render.use_motion_blur=False
    scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
    scene.view_settings.exposure=0; scene.view_settings.gamma=1
    scene.world=bpy.data.worlds.new('JD1_NeutralWorld'); scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background'); bg.inputs['Color'].default_value=(.32,.36,.40,1); bg.inputs['Strength'].default_value=.35
    actor=bpy.data.collections.new('JD1_Actor'); scene.collection.children.link(actor)
    carrier=bpy.data.objects.new('JD1_PREVIEW_ONLY_Carrier',None); actor.objects.link(carrier)
    carrier.empty_display_type='PLAIN_AXES'; carrier.empty_display_size=.25
    carrier['purpose']='Preview height only. Exclude from future pose export and restore rig parent baseline.'
    rig=source.copy(); rig.data=source.data.copy(); rig.name='JD1_Player_Rig'; actor.objects.link(rig)
    rig.data.name='JD1_Player_RigData'; rig.hide_render=False; rig.hide_viewport=False
    mesh=body.copy(); mesh.name='JD1_Player_Mesh'; actor.objects.link(mesh)
    mesh.parent=rig; mesh.matrix_parent_inverse=body.matrix_parent_inverse.copy()
    mesh.hide_render=False; mesh.hide_viewport=False
    for md in mesh.modifiers:
        if md.type=='ARMATURE':md.object=rig
    bpy.context.window.scene=scene
    # Evaluate the existing unarmed idle on the isolated clone, then retain its offsets.
    scene.frame_set(1); bpy.context.view_layer.update()
    idle={p.name:{'location':tuple(p.location),'scale':tuple(p.scale),'rotation_mode':p.rotation_mode,
          'rotation_quaternion':tuple(p.rotation_quaternion),'rotation_euler':tuple(p.rotation_euler)} for p in rig.pose.bones}
    dg=bpy.context.evaluated_depsgraph_get(); evaluated=mesh.evaluated_get(dg)
    pts=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
    floor=min(v.z for v in pts); height=max(v.z for v in pts)-floor
    rig.animation_data_clear()
    pose=bpy.data.actions.new(POSE); pose.use_fake_user=True
    rig.animation_data_create(); rig.animation_data.action=pose
    # Parent at identity preserves the inspected rig transform and avoids double motion.
    rig.parent=carrier; rig.matrix_parent_inverse=Matrix.Identity(4)
    scene['jump_rig']=rig.name; scene['jump_carrier']=carrier.name
    scene['jump_height_H']=height; scene['jump_floor_z']=floor; scene['jump_apex_h']=.35*height
    scene['jump_status']='Blender-only study; awaiting user review; no runtime export'
    (OUT/'idle_baseline.json').write_text(json.dumps(idle,indent=2))
    # Neutral floor is fixed at the actual standing sole, not the object origin.
    stage=bpy.data.collections.new('JD1_ReviewStage'); scene.collection.children.link(stage)
    md=bpy.data.meshes.new('JD1_FloorMesh'); md.from_pydata([(-100,-100,floor),(100,-100,floor),(100,100,floor),(-100,100,floor)],[],[(0,1,2,3)])
    ground=bpy.data.objects.new('JD1_FixedFloor',md); stage.objects.link(ground)
    material=bpy.data.materials.new('JD1_NeutralFloor'); material.diffuse_color=(.19,.22,.245,1); material.use_nodes=True
    bs=material.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=material.diffuse_color
    bs.inputs['Roughness'].default_value=.9; ground.data.materials.append(material)
    for name,loc,power,size,color in [('Key',(-3,-4,6),700,4,(1,.94,.86)),('Fill',(4,-1,4),430,5,(.84,.92,1)),('Rim',(0,4,5),500,4,(.92,.96,1))]:
        data=bpy.data.lights.new('JD1_'+name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
        light=bpy.data.objects.new(data.name,data); stage.objects.link(light); light.location=loc
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    target=(0,0,1.22)
    cams={
        'THREE_QUARTER':camera(scene,'JD1_Gameplay',(3,-6,5.6),target,3.5),
        'SIDE':camera(scene,'JD1_Side',(6,0,2.7),target,3.2),
        'FRONT':camera(scene,'JD1_Front',(0,-7,2.25),target,3.2),
        'BACK':camera(scene,'JD1_Back',(0,7,2.25),target,3.2),
    }
    scene['review_cameras']=json.dumps({key:ob.name for key,ob in cams.items()}); scene.camera=cams['THREE_QUARTER']
    marker_names={1:'READY',3:'ANTICIPATE - feet planted',5:'PUSH - last support',6:'LIFTOFF',9:'AIR SILHOUETTE',12:'APEX 0.35H',16:'DESCEND',19:'CONTACT',21:'ABSORB - torso',22:'ARM FOLLOW-THROUGH',25:'RECOVER / IDLE'}
    for frame,name in marker_names.items():scene.timeline_markers.new(name,frame=frame)
    animate(scene,rig,carrier,idle)
    bpy.context.view_layer.objects.active=rig; rig.select_set(True); rig.show_in_front=False
    scene.frame_set(12)
    assert all(signature(bpy.data.actions[n])==h for n,h in baseline.items())
    manifest={'scene':scene.name,'rig':rig.name,'mesh':mesh.name,'source_rig':source.name,'source_mesh':body.name,
              'pose_action':pose.name,'pose_slot':rig.animation_data.action_slot.identifier,'carrier':carrier.name,'carrier_action':carrier.animation_data.action.name,
              'height_H':height,'floor_z':floor,'carrier_apex':.35*height,'fps':30,'frames':[1,25],
              'lead_leg':'Leg.R (+48 degrees local X at apex; forward -Y)','low_leg':'Leg.L (-14 degrees local X at apex)',
              'markers':marker_names,'original_action_hashes':baseline,
              'limits':'No knee/ankle joints or IK; pelvis stays fixed during support. Compression uses torso/arms, no scaling.',
              'status':'Awaiting user review; Blender-only; no gameplay changes'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    return manifest

def animate(scene,rig,carrier,idle):
    """Art-directed asymmetric pose; support legs never move during grounded phases."""
    pose=rig.animation_data.action
    for c in curves(pose):
        # Reruns only touch this newly authored action, never shared source Actions.
        c.keyframe_points.clear()
    # Each tuple: spine lean, chest twist, head compensation, lead/low leg,
    # high arm forward/outward, low arm forward/outward, elbows R/L.
    keys={
        1: (0,0,0, 0,0, 0,0,0,0, 0,0),
        2: (0,0,0, 0,0, 0,0,0,0, 0,0),
        3: (10,-2,-5, 0,0, -16,-9,-12,10, 12,10),
        5: (-2,1,1, 0,0, 15,-16,8,20, 20,15),
        6: (2,2,-1, 12,-5, 40,-25,18,33, 26,18),
        9: (9,6,-5, 44,-13, 95,-38,24,64, 25,20),
        12:(10,7,-6, 48,-14, 100,-40,26,67, 25,22),
        14:(9,6,-5, 47,-13, 98,-39,25,65, 24,22),
        16:(7,4,-4, 34,-9, 82,-32,23,57, 23,20),
        18:(3,1,-1, 9,-2, 36,-20,15,31, 16,14),
        19:(4,0,-1, 0,0, 21,-13,10,20, 13,12),
        21:(16,-2,-6, 0,0, -5,-10,-5,13, 22,20),
        22:(12,-1,-8, 0,0, -13,-8,-10,10, 24,22),
        23:(6,0,-5, 0,0, -6,-5,-5,7, 14,12),
        24:(0,0,0, 0,0, 0,0,0,0, 0,0),
        25:(0,0,0, 0,0, 0,0,0,0, 0,0),
    }
    for f,v in keys.items():
        lean,twist,head,lead,low,rf,ro,lf,lo,re,le=v
        rotations={'Spine':(lean*.4,0,0),'Chest':(lean*.6,twist,0),'Head':(head,-twist*.5,0),
                   'Leg.R':(lead,0,0),'Leg.L':(low,0,0),'UpperArm.R':(rf,0,ro),'UpperArm.L':(lf,0,lo),
                   'ForeArm.R':(re,0,0),'ForeArm.L':(le,0,0)}
        for p in rig.pose.bones:
            base=idle[p.name]; p.location=base['location']; p.scale=base['scale']
            # Existing pose translation channel: a small shoulder glide opens
            # clearance before rotating the square arm corners beside the head.
            # Neutral returns exactly to the authored 32 mm shoulder inset.
            # No rest-bone, mesh, scale, or limb-length edits.
            if 2<=f<=24 and p.name.startswith('UpperArm'):
                p.location.x += -.008 if p.name.endswith('.L') else .008
            # Preserve bone rotation modes. Baseline channels (Root/Hips/WeaponCarrier)
            # remain constant; key only genuine pose joints and shoulder offsets.
            angles=rotations.get(p.name,(0,0,0))
            # Spread before swing: XYZ would collapse lateral separation when
            # the forward swing approaches 90 degrees (foreshortened zombie arms).
            e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if p.name.startswith('UpperArm') else 'XYZ')
            if p.rotation_mode=='QUATERNION':
                p.rotation_quaternion=e.to_quaternion(); prop='rotation_quaternion'
            else:
                p.rotation_euler=e; prop='rotation_euler'
            if p.name in rotations:p.keyframe_insert(prop,frame=f,group=p.name)
            if p.name.startswith('UpperArm'):p.keyframe_insert('location',frame=f,group=p.name)
    for c in curves(pose):
        c.extrapolation='CONSTANT'
        for k in c.keyframe_points:
            k.interpolation='BEZIER'; k.handle_left_type='AUTO_CLAMPED'; k.handle_right_type='AUTO_CLAMPED'
    # Exact quadratic Bézier flight: tangent = d/dframe 4h*u*(1-u).
    carrier.animation_data_clear(); travel=bpy.data.actions.get(TRAVEL) or bpy.data.actions.new(TRAVEL)
    travel.use_fake_user=True; carrier.animation_data_create(); carrier.animation_data.action=travel
    h=scene['jump_apex_h']
    for f,z in [(1,0),(5,0),(12,h),(19,0),(25,0)]:
        carrier.location=(0,0,z); carrier.keyframe_insert('location',index=2,frame=f,group='PREVIEW ONLY')
    c=curves(travel)[0]; c.extrapolation='CONSTANT'
    ks=c.keyframe_points
    for k in ks:k.interpolation='BEZIER'; k.handle_left_type='FREE'; k.handle_right_type='FREE'
    for i,k in enumerate(ks):
        f,z=k.co
        left=(f-ks[i-1].co.x)/3 if i else 1
        right=(ks[i+1].co.x-f)/3 if i<len(ks)-1 else 1
        slope=4*h/14*(1-2*(f-5)/14) if 5<=f<=19 else 0
        ls=slope if 5<f<=19 else 0; rs=slope if 5<=f<19 else 0
        k.handle_left=(f-left,z-ls*left); k.handle_right=(f+right,z+rs*right)
    scene.frame_set(12); bpy.context.view_layer.update()

if __name__=='__main__':
    result=build()
