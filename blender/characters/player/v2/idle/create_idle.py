"""Author a cyclic idle through Blender MCP; never edits mesh, weights or skeleton."""
import bpy, math, json, hashlib
from mathutils import Vector, Matrix
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/v2/idle')
rig=bpy.data.objects['Player_Rig']; mesh=bpy.data.objects['Player_Base']; scene=bpy.context.scene
assert bpy.data.actions.get('Player_Idle') is None, 'Do not overwrite an existing action'

def signature():
    data={
        'vertices':[(list(v.co),[(g.group,g.weight) for g in v.groups]) for v in mesh.data.vertices],
        'polygons':[(list(p.vertices),p.material_index) for p in mesh.data.polygons],
        'materials':[(m.name,list(m.diffuse_color),[(n.name,n.type,[(i.name,list(i.default_value) if hasattr(i.default_value,'__len__') and not isinstance(i.default_value,str) else i.default_value) for i in n.inputs if hasattr(i,'default_value') and isinstance(i.default_value,(int,float,str,Vector,bpy.types.bpy_prop_array))]) for n in m.node_tree.nodes]) for m in mesh.data.materials],
        'bones':[(b.name,b.parent.name if b.parent else None,list(b.head_local),list(b.tail_local),[list(row) for row in b.matrix_local],b.use_deform,b.use_connect) for b in rig.data.bones],
        'pose_config':[(p.name,p.rotation_mode,list(p.lock_location),list(p.lock_rotation),list(p.lock_scale),len(p.constraints)) for p in rig.pose.bones],
    }
    return hashlib.sha256(json.dumps(data,sort_keys=True,default=str).encode()).hexdigest()

original_signature=signature()
rest={p.name:p.bone.matrix_local.copy() for p in rig.pose.bones}
names=[p.name for p in rig.pose.bones if p.name!='Root']
def rot(name,x=0,y=0,z=0):
    rig.pose.bones[name].rotation_euler=tuple(math.radians(a) for a in (x,y,z))

def segment_matrix(name,head,tail):
    original=rest[name]
    old_dir=original.to_3x3() @ Vector((0,1,0))
    new_dir=(tail-head).normalized()
    q=old_dir.rotation_difference(new_dir)
    mat=(q.to_matrix() @ original.to_3x3()).to_4x4()
    mat.translation=head
    return mat

def pose(frame):
    t=2*math.pi*(frame-1)/48
    for p in rig.pose.bones:
        p.location=(0,0,0); p.rotation_euler=(0,0,0); p.scale=(1,1,1)
    # Alert stance: tiny lowered center of mass leaves room for planted-foot flexion.
    displacement=Vector((.006*math.sin(t),.001*math.sin(t-.3),-.004+.0009*math.cos(t)))
    rig.pose.bones['Hips'].location=rest['Hips'].to_3x3().transposed() @ displacement
    rot('Hips',.15*math.sin(t-.2),.22*math.sin(t),.28*math.sin(t))
    rot('Spine',-.30+.40*math.cos(t),-.28*math.sin(t-.15),-.34*math.sin(t))
    rot('Chest',.45+.65*math.cos(t-.18),.32*math.sin(t-.25),-.20*math.sin(t-.12))
    rot('Neck',-.18-.18*math.cos(t-.35),-.22*math.sin(t-.5),.15*math.sin(t-.4))
    rot('Head',-.35+.22*math.sin(t-.45),.65*math.sin(t-.48),.22*math.sin(t-.35))
    for s,sign in [('L',1),('R',-1)]:
        phase=t-(.34 if sign==1 else .47)
        rot('Clavicle.'+s,.12*math.sin(phase),.16*math.sin(phase),sign*(.25+.38*math.cos(phase)))
        rot('UpperArm.'+s,-1.6+.55*math.sin(phase-.16),sign*(.25+.22*math.sin(phase-.12)),sign*(.45+.30*math.cos(phase-.10)))
        rot('Forearm.'+s,-3.5+(.7 if sign==1 else .55)*math.sin(phase-.28),sign*.25*math.sin(phase-.3),sign*.12*math.cos(phase-.18))
        rot('Hand.'+s,.18*math.sin(phase-.48),sign*.22*math.sin(phase-.42),sign*.20)
    bpy.context.view_layer.update()
    # Offline analytic two-bone solve. Only ordinary rotation keys are stored;
    # no new constraints, control bones, drivers or runtime IK are introduced.
    for s in ['L','R']:
        thigh=rig.pose.bones['Thigh.'+s]; shin=rig.pose.bones['Shin.'+s]; foot=rig.pose.bones['Foot.'+s]
        hip=thigh.head.copy(); ankle=rest['Foot.'+s].translation.copy()
        l1=thigh.bone.length; l2=shin.bone.length
        vector=ankle-hip; d=vector.length; axis=vector.normalized()
        assert d < l1+l2
        along=(l1*l1-l2*l2+d*d)/(2*d)
        pole=Vector((0,-1,0)); bend=(pole-axis*pole.dot(axis)).normalized()
        knee=hip+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
        thigh.matrix=segment_matrix(thigh.name,hip,knee)
        bpy.context.view_layer.update()
        shin.matrix=segment_matrix(shin.name,knee,ankle)
        bpy.context.view_layer.update()
        foot.matrix=rest[foot.name]
        bpy.context.view_layer.update()
        for p in (thigh,shin,foot):
            assert p.location.length < 1e-5
            p.location=(0,0,0); p.scale=(1,1,1)
    bpy.context.view_layer.update()
    values={('pose.bones["'+n+'"].rotation_euler',i):rig.pose.bones[n].rotation_euler[i] for n in names for i in range(3)}
    values.update({('pose.bones["Hips"].location',i):rig.pose.bones['Hips'].location[i] for i in range(3)})
    return values

frames=list(range(1,50,6))
samples={f:pose(f) for f in frames}
# Exact duplicate closure, with matched periodic derivatives at both sides.
samples[49]=samples[1].copy()
eps=.1
slopes={}
for f in frames:
    prev=pose(f-eps); nxt=pose(f+eps)
    slopes[f]={k:(nxt[k]-prev[k])/(2*eps) for k in prev}
slopes[49]=slopes[1].copy()
pose(1)
action=bpy.data.actions.new('Player_Idle')
rig.animation_data_create(); rig.animation_data.action=action
for f in frames:
    for (path,index),value in samples[f].items():
        name=path.split('"')[1]; prop=path.rsplit('.',1)[1]
        getattr(rig.pose.bones[name],prop)[index]=value
        rig.keyframe_insert(data_path=path,index=index,frame=f,group=name)
curves=[fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
for fc in curves:
    k=(fc.data_path,fc.array_index)
    for point in fc.keyframe_points:
        f=int(round(point.co.x)); v=samples[f][k]; slope=slopes[f][k]
        point.interpolation='BEZIER'
        point.handle_left_type='FREE'; point.handle_right_type='FREE'
        point.handle_left=(f-2,v-2*slope); point.handle_right=(f+2,v+2*slope)
    fc.modifiers.new('CYCLES')
    fc.update()
action.use_fake_user=True
action.use_frame_range=True; action.frame_start=1; action.frame_end=49
action['loop_period_frames']=48
action['playback_range']='1-48 at 24 FPS; frame 49 equals frame 1 and supplies seam tangents.'
action['authoring']='Eight sparse poses plus closure; periodic Bezier tangents; delayed arms, asymmetrical shoulders; analytically planted feet.'
scene.frame_start=1; scene.frame_end=48; scene.render.fps=24; scene.render.fps_base=1
scene.frame_set(1)
assert signature()==original_signature, 'Asset data must remain unchanged'
(OUT/'source_signature.txt').write_text(original_signature)
scene.render.filepath=str(OUT/'Player_Idle_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_voxel_v2_idle.blend'))
result={'action':action.name,'frames':frames,'playback':[1,48],'fps':24,'curves':len(curves),'keys':sum(len(fc.keyframe_points) for fc in curves),'bones':names,'asset_unchanged':True}
