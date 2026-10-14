"""Independent evaluated-geometry checks. Run in fresh Blender after build."""
import bpy, json, math, sys
from pathlib import Path

OUT=Path(__file__).resolve().parent
TARGET=(OUT.parent if OUT.parent.name=='showcase' else OUT)/'Mobs_Animation_Library.blend'
SOURCE=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation_v2/zombie_animation_v2.blend')
assert TARGET.exists(), 'Mobs Animation Library has not been created'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
src_rig=bpy.data.objects['Zombie_Cuboid_Rig']
src_mesh=bpy.data.objects['Zombie_Cuboid_Base']
rest={b.name:(b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in src_rig.data.bones}
geometry=[tuple(v.co) for v in src_mesh.data.vertices]
uvs=[tuple(v.uv) for v in src_mesh.data.uv_layers.active.data]
weights=[[(g.group,g.weight) for g in v.groups] for v in src_mesh.data.vertices]
bpy.ops.wm.open_mainfile(filepath=str(TARGET))
scene=bpy.context.scene;rig=bpy.data.objects['Zombie_Cuboid_Rig'];mesh=bpy.data.objects['Zombie_Cuboid_Base']
assert {b.name:(b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in rig.data.bones}==rest
assert [tuple(v.co) for v in mesh.data.vertices]==geometry
assert [tuple(v.uv) for v in mesh.data.uv_layers.active.data]==uvs
assert [[(g.group,g.weight) for g in v.groups] for v in mesh.data.vertices]==weights
names={'Zombie_Idle_Original_V1','Zombie_Walk_Original_V1'}
assert names.issubset({a.name for a in bpy.data.actions})
leg_indices={side:[v.index for v in mesh.data.vertices if any(mesh.vertex_groups[g.group].name=='Leg.'+side for g in v.groups)] for side in ['L','R']}

def vertices(frame):
    scene.frame_set(math.floor(frame),subframe=frame%1)
    dg=bpy.context.evaluated_depsgraph_get();ob=mesh.evaluated_get(dg)
    return [ob.matrix_world@v.co for v in ob.data.vertices]

report={'rig_mesh_uv_weights_preserved':True,'actions':{}}
for name in sorted(names):
    action=bpy.data.actions[name];assert action['review_status']=='Pending'
    for bone in rig.pose.bones:bone.location=(0,0,0);bone.rotation_euler=(0,0,0);bone.scale=(1,1,1)
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    N=120 if 'Idle' in name else 42
    first=vertices(1);last=vertices(N+1)
    seam=max((a-b).length for a,b in zip(first,last));assert seam<1e-5,(name,seam)
    h=.002
    va=vertices(1+h);vb=vertices(1);vc=vertices(N+1);vd=vertices(N+1-h)
    vel=max(((a-b)/h-(c-d)/h).length*30 for a,b,c,d in zip(va,vb,vc,vd))
    assert vel<.012,(name,'velocity seam',vel)
    low=10;support_error=0;idle_drift=0;scale_error=0;root_error=0;anchors={};stance_drift=0;rigidity_error=0
    for j in range(N*4+1):
        f=1+j/4;vs=vertices(f)
        for pb in rig.pose.bones:
            scale_error=max(scale_error,max(abs(x-1) for x in pb.scale))
        root_error=max(root_error,max(abs(rig.pose.bones['Root'].matrix_basis[r][c]-(1 if r==c else 0)) for r in range(4) for c in range(4)))
        floor={s:min(vs[i].z for i in ids) for s,ids in leg_indices.items()}
        for side,ids in leg_indices.items():
            for ia in ids:
                for ib in ids:
                    rigidity_error=max(rigidity_error,abs((vs[ia]-vs[ib]).length-(mesh.data.vertices[ia].co-mesh.data.vertices[ib].co).length))
            if 'Walk' in name:
                t=(f-1)/N;offset=0 if side=='L' else .52;p=(t-offset)%1
                # Distinct physical support edges; exclude the flat-sole exchange.
                edge=1 if .01<p<.64*.43 else -1 if .64*.52<p<.63 else 0
                if edge:
                    sole=[i for i in ids if mesh.data.vertices[i].co.z<.0001 and mesh.data.vertices[i].co.y*edge>0]
                    from mathutils import Vector
                    center=sum((vs[i] for i in sole),Vector())/len(sole)
                    center.y-=.728*t
                    key=(side,math.floor(t-offset),edge)
                    if key in anchors:stance_drift=max(stance_drift,(center-anchors[key]).length)
                    else:anchors[key]=center.copy()
        low=min(low,*floor.values())
        support_error=max(support_error,abs(min(floor.values())-.0005))
        if 'Idle' in name:idle_drift=max(idle_drift,max((vs[i]-first[i]).length for ids in leg_indices.values() for i in ids))
    assert low>=-.0003,(name,'floor',low)
    assert support_error<.001,(name,'support',support_error)
    assert scale_error<1e-6 and root_error<1e-6
    assert rigidity_error<.00001,(name,'rigid lengths',rigidity_error)
    assert stance_drift<.001,(name,'nominal-speed stance drift',stance_drift)
    if 'Idle' in name:assert idle_drift<.0001,(name,idle_drift)
    # Compare the actual periodic curve endpoint slopes, independent of float-noisy mesh differentiation.
    slope_error=0
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    a=curve.keyframe_points[0];b=curve.keyframe_points[-1]
                    da=(a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x)
                    db=(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)
                    slope_error=max(slope_error,abs(da-db))
    assert slope_error<.0001,(name,'FCurve tangent seam',slope_error)
    report['actions'][name]={'samples':N*4+1,'pose_seam_m':seam,'velocity_seam_m_s':vel,'curve_tangent_seam_error_per_frame':slope_error,'minimum_sole_z_m':low,'support_height_error_m':support_error,'idle_foot_drift_m':idle_drift,'nominal_speed_support_edge_drift_m':stance_drift,'rigidity_length_error_m':rigidity_error,'scale_error':scale_error,'root_basis_error':root_error}
(OUT/'validation_geometry.json').write_text(json.dumps(report,indent=2))
print('GEOMETRY_VALIDATION',json.dumps(report))
