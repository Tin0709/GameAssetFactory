"""Shared R2 study helpers. No production integration or scene mutation on import."""
import bpy,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Euler,Quaternion
BASE=Path(__file__).resolve().parent;OUT=BASE/'turning_study_r2_review'
DEV=BASE/'player_locomotion_turning_study.blend'
PERIOD={'Walk':16,'Sprint':13}
BODY=['Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R']
def curves(a):return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
def digest(a):
    return hashlib.sha256(repr(([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after) for m in c.modifiers if m.type=='CYCLES']) for c in curves(a)],[(m.name,m.frame) for m in a.pose_markers],dict(a.items()))).encode()).hexdigest()
def geometry():
    return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bone_signature(rig):
    return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
def preserve():
    return {'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),
      'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'},
      'files':{n:hashlib.sha256((BASE/n).read_bytes()).hexdigest() for n in ['player_locomotion_reference_study.blend','player_cuboid_weapon_animation_dev.blend']}}
def check_preserved(p):
    assert all(digest(bpy.data.actions[n])==h for n,h in p['actions'].items())
    geo=geometry();assert all(geo[n]==h for n,h in p['geometry'].items())
    assert all(json.dumps(bone_signature(bpy.data.objects[n]),sort_keys=True)==json.dumps(sig,sort_keys=True) for n,sig in p['rigs'].items())
    assert all(hashlib.sha256((BASE/n).read_bytes()).hexdigest()==h for n,h in p['files'].items())
def copy_character(scene,label):
    source=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
    r=source.copy();r.data=source.data.copy();r.animation_data_clear();r.name='R2_'+label+'_Rig';scene.collection.objects.link(r)
    r.location=(0,0,0);r.rotation_euler=(0,0,0);r.scale=(1,1,1)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    m=mesh.copy();m.name='R2_'+label+'_Mesh';m.animation_data_clear();scene.collection.objects.link(m);m.parent=r;m.matrix_parent_inverse=mesh.matrix_parent_inverse.copy()
    for md in m.modifiers:
        if md.type=='ARMATURE':md.object=r
    r.hide_render=False;m.hide_render=False;r.hide_viewport=False;m.hide_viewport=False;r.animation_data_create()
    return r,m
def assign(r,a):
    r.animation_data_create();r.animation_data.action=a
    if a and len(a.slots):r.animation_data.action_slot=a.slots[0]
def sample(r,scene,a,f):
    assign(r,a)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    return {n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_euler.copy()) for n in BODY}
def apply(r,ps):
    assign(r,None)
    for n,(loc,rot) in ps.items():r.pose.bones[n].location=loc;r.pose.bones[n].rotation_euler=rot
    bpy.context.view_layer.update()
def mix(a,b,w):
    # Absolute-pose interpolation, shared normalized phase. Never sum complete poses.
    return {n:(a[n][0].lerp(b[n][0],w),a[n][1].to_quaternion().slerp(b[n][1].to_quaternion(),w).to_euler('XYZ',a[n][1])) for n in BODY}
def key_pose(r,a,f,ps):
    assign(r,a)
    for n,(loc,rot) in ps.items():
        p=r.pose.bones[n];p.location=loc;p.rotation_euler=rot
        p.keyframe_insert('location',frame=f,group=n);p.keyframe_insert('rotation_euler',frame=f,group=n)
def periodic(a,period):
    for c in curves(a):
        ks=c.keyframe_points;count=len(ks)-1;step=period/count;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            j=i%count;slope=(ys[(j+1)%count]-ys[(j-1)%count])/(2*step)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        if not any(m.type=='CYCLES' for m in c.modifiers):c.modifiers.new('CYCLES')
        c.update()
def mesh_points(mesh):
    return {n:np.array([tuple(v.co) for v in mesh.data.vertices if any(g.group==mesh.vertex_groups[n].index and g.weight>.999 for g in v.groups)]) for n in ['Head','Chest','Arm.L','Arm.R','Leg.L','Leg.R']}
def transformed(r,points,n):
    m=np.array(r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted());return points[n]@m[:3,:3].T+m[:3,3]
def floor_min(r,points):return min(float(transformed(r,points,n)[:,2].min()) for n in ['Leg.L','Leg.R'])
def camera(s,name,pos,target,scale):
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
def smooth(x):x=max(0,min(1,x));return x*x*x*(x*(x*6-15)+10)
