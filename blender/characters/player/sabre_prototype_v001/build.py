"""Build the authored fidelity-test character and all editable actions.

All inputs are the adjacent original geometry/motion Python definitions.
No MD2 asset, texture, rig or source animation channel is opened here.
"""
from pathlib import Path
import sys, math, json, hashlib
import bpy
from mathutils import Vector, Quaternion, Matrix
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import geometry, motion
FPS=120
DOWN=Vector((0,0,-1))
def Q(axis,angle):return Quaternion(axis,math.radians(angle))

def shaft(pitch,splay,heading):
    p,s=math.radians(pitch),math.radians(splay)
    direction=Vector((math.sin(s),-math.sin(p)*math.cos(s),-math.cos(p)*math.cos(s)))
    return Q((0,0,1),heading)@DOWN.rotation_difference(direction)

def blade(heading,elevation,roll):
    y,e=math.radians(heading),math.radians(elevation)
    d=Vector((math.sin(y)*math.cos(e),-math.cos(y)*math.cos(e),math.sin(e)))
    side=Vector((0,0,1))-d*d.z
    if side.length<.001:side=Vector((1,0,0))-d*d.x
    side.normalize();side=Quaternion(d,math.radians(roll))@side
    z=-d;y=z.cross(side)
    return Matrix((side,y,z)).transposed().to_quaternion()

def apply_pose(rig,values,name):
    y,lean,side,lp,ls,rp,rs,ll,rl,hy,hu,wy,we,wr,hz,lls,rls=values
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION';b.rotation_quaternion=(1,0,0,0)
        b.location=(0,0,0);b.scale=(1,1,1)
    body=Q((0,0,1),y)@Q((1,0,0),lean)@Q((0,1,0),side)
    rig.pose.bones['Body'].rotation_quaternion=body
    rig.pose.bones['Head'].rotation_quaternion=body.inverted()@(Q((0,0,1),hy)@Q((1,0,0),-hu))
    arms={}
    for label,p,s in [('L',lp,ls),('R',rp,rs)]:
        world=shaft(p,s,y);arms[label]=world
        rig.pose.bones['Arm.'+label].rotation_quaternion=body.inverted()@world
    for label,p,s in [('L',ll,lls),('R',rl,rls)]:
        world=shaft(p,s,y)
        b=rig.pose.bones['Leg.'+label];b.rotation_quaternion=world
        # An authored rigid-foot clearance adapter, no extra body/hip bounce.
        # Keep the lowest corner at the ground, with a small swing-foot lift.
        if not name.startswith('Jump') and name!='AirAttack':
            bottom=min((world@Vector((x,yy,-.75))).z for x in [-.125,.125] for yy in [-.125,.125])
            b.location.z=-.75-bottom
    rig.pose.bones['Hips'].location.z=hz
    # Full-size sabre; wrist twist reconstructed independently from sparse
    # blade-direction observations. No source nonuniform stretch/shear copied.
    rig.pose.bones['Weapon'].rotation_quaternion=arms['R'].inverted()@blade(wy,we,wr)

def action_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves

def studio(scene):
    world=bpy.data.worlds.new('Sabre neutral studio');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.10,.14,.18,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45;scene.world=world
    data=bpy.data.cameras.new('Showcase Camera');cam=bpy.data.objects.new('Showcase Camera',data)
    scene.collection.objects.link(cam);cam.location=(3.4,-6,3.2)
    cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=3.9;scene.camera=cam
    for label,position,energy,color in [('Key',(2,-4,5),450,(1,.88,.76)),('Fill',(-3,-1,3),230,(.65,.8,1)),('Rim',(2,3,4),500,(.8,.9,1))]:
        data=bpy.data.lights.new(label,'AREA');data.energy=energy;data.shape='DISK';data.size=4;data.color=color
        obj=bpy.data.objects.new(label,data);scene.collection.objects.link(obj);obj.location=position
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    mesh=bpy.data.meshes.new('Quiet floor');mesh.from_pydata([(-20,-20,-.006),(20,-20,-.006),(20,20,-.006),(-20,20,-.006)],[],[(0,1,2,3)])
    obj=bpy.data.objects.new('Quiet floor',mesh);scene.collection.objects.link(obj)
    mat=bpy.data.materials.new('Quiet studio floor');mat.diffuse_color=(.08,.115,.14,1);obj.data.materials.append(mat)
    return cam

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.name='SABRE_CHARACTER_COMBAT_SHOWCASE'
    scene.render.fps=FPS;scene.render.fps_base=1;scene.sync_mode='FRAME_DROP'
    scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'
    result=geometry.build(scene,HERE)
    rig=result['rig'];rig.name='SabrePrototypeRig';rig.show_in_front=False
    result['body'].name='SabrePrototypeBody';result['face'].name='SabrePrototypeFace';result['sabre'].name='SabrePrototypeSabre'
    rig.animation_data_create()
    actions={};entries={};last_q={}
    for name,row in motion.CLIPS.items():
        action=bpy.data.actions.new('Sabre_'+name);action.use_fake_user=True
        rig.animation_data.action=action
        end=round(row['duration']*FPS)
        last_q={}
        for frame in range(end+1):
            apply_pose(rig,motion.pose(name,frame/FPS),name)
            for b in rig.pose.bones:
                q=b.rotation_quaternion
                if b.name in last_q and q.dot(last_q[b.name])<0:q.negate()
                last_q[b.name]=q.copy()
                b.keyframe_insert('rotation_quaternion',frame=1+frame,group=b.name)
                b.keyframe_insert('location',frame=1+frame,group=b.name)
                b.keyframe_insert('scale',frame=1+frame,group=b.name)
        for curve in action_curves(action):
            for point in curve.keyframe_points:point.interpolation='LINEAR'
        action.asset_mark();action['evidence']=row['evidence'];action['source_family']=row.get('source_name') or 'authored'
        actions[name]=action
        entries[name]=dict(row,action=action.name,frames=[1,end+1])
    # Export only fresh authored character inputs; studio and NLA reel follow.
    rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
    scene.frame_set(1)
    markers=[]
    for label,point in [('SabreGrip',(0,0,0)),('SabreBladeBase',(0,0,-.133)),('SabreBladeTip',(.246,0,-1.458))]:
        obj=bpy.data.objects.new(label,None);scene.collection.objects.link(obj)
        obj.parent=rig;obj.parent_type='BONE';obj.parent_bone='Weapon'
        obj.location=Vector(point)-Vector((0,rig.data.bones['Weapon'].length,0))
        obj.empty_display_type='PLAIN_AXES';obj.empty_display_size=.03
        markers.append(obj)
    for obj in bpy.context.selected_objects:obj.select_set(False)
    for obj in [rig,result['body'],result['face'],result['sabre'],*markers]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    options=dict(filepath=str(HERE/'Sabre_Character_Authored.glb'),export_format='GLB',
        use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',
        export_force_sampling=True,export_frame_step=1,export_skins=True,export_morph=True,
        export_anim_slide_to_zero=True,
        export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=False,
        export_anim_single_armature=True,export_nla_strips=False)
    supported={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{k:v for k,v in options.items() if k in supported})
    # The default file plays the complete action reel with no addon required.
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name='ALL ACTIONS - select clips with the prototype sidebar'
    cursor=1
    for name,row in entries.items():
        strip=track.strips.new(name,int(cursor),actions[name])
        strip.action_slot=actions[name].slots[0]
        strip.extrapolation='NOTHING';strip.blend_type='REPLACE';strip.use_auto_blend=False
        strip.repeat=2 if row['loop'] else 1
        scene.timeline_markers.new(name,frame=int(cursor))
        cursor=strip.frame_end+FPS*.2
    scene.frame_start=1;scene.frame_end=math.ceil(cursor)
    scene.frame_set(1)
    cam=studio(scene)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.region_3d.view_perspective='CAMERA';space.shading.type='MATERIAL'
                space.overlay.show_overlays=False
    readme=bpy.data.texts.new('READ ME - SABRE PROTOTYPE')
    readme.write('Original asset / source-informed pose recreation, not imported game tracks.\n'
      'Space plays the complete22-action NLA reel. Timeline markers name each clip.\n'
      'For select/play/expression controls use Open Sabre Showcase.cmd beside this file.\n'
      'Alternatively disable NLA and choose a Sabre_* Action in the Action Editor.\n'
      'Face morphs: Focused and Blink. All geometry/UV/pixels are newly authored.\n'
      'Rig has rigid limbs; no elbows or knees. Full-size sabre uses a fixed wrist pivot.\n'
      'Dimensions and durations match recovered measurements. Curves/mount/timing gates approximate.\n'
      'Sabre-to-1H_Medium assignment is inferred; no native notify times recovered.\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Sabre_Character_Showcase.blend'))
    # Stills are genuine Blender renders of the saved asset, not mockups.
    preview_dir=HERE/'previews';preview_dir.mkdir(exist_ok=True)
    rig.animation_data.use_nla=False
    for name,fraction in [('Idle',0),('Walk',.25),('Run',.25),('Attack1',.24),('Attack2',.50),('Attack3',.52)]:
        rig.animation_data.action=actions[name];rig.animation_data.action_slot=actions[name].slots[0]
        f=1+motion.CLIPS[name]['duration']*FPS*fraction;scene.frame_set(int(f),subframe=f-int(f))
        scene.render.filepath=str(preview_dir/(name+'.png'));bpy.ops.render.render(write_still=True)
    face=result['face']
    rig.animation_data.action=actions['CombatReady'];rig.animation_data.action_slot=actions['CombatReady'].slots[0]
    scene.frame_set(1)
    old_scale=cam.data.ortho_scale;old_position=cam.location.copy();old_rot=cam.rotation_euler.copy()
    cam.location=(0,-4,1.75);cam.rotation_euler=(Vector((0,0,1.75))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.85
    for label,focused,blink in [('FaceNeutral',0,0),('FaceFocused',1,0),('FaceBlink',0,1)]:
        face.data.shape_keys.key_blocks['Focused'].value=focused;face.data.shape_keys.key_blocks['Blink'].value=blink
        scene.render.filepath=str(preview_dir/(label+'.png'));bpy.ops.render.render(write_still=True)
    face.data.shape_keys.key_blocks['Focused'].value=0;face.data.shape_keys.key_blocks['Blink'].value=0
    manifest={'scope':'Internal fidelity prototype; fresh geometry/UV/atlas, source-informed sparse authored curves.',
      'rig_bones':list(rig.data.bones.keys()),'axis':'BlenderZup,forward-Y; glTFYup,forward+Z',
      'metrics':result['metrics'],'clips':entries,'glb':'Sabre_Character_Authored.glb',
      'body_sha256':hashlib.sha256((HERE/'Sabre_Character_Authored.glb').read_bytes()).hexdigest(),
      'approximation':'No source TRS, UV, texture or rig copied. Source weapon shear omitted; new rigid full-size mount.',
      'authored_input_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE/'geometry.py',HERE/'motion.py',HERE/'build.py']}}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('SABRE_BUILD_SAVED',len(entries),'actions')

if __name__=='__main__':build()
