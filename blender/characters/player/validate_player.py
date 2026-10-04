"""Temporary pose checks; creates no actions and always restores the rest pose."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player')
mesh=bpy.data.objects['Player_Base']
rig=bpy.data.objects['Player_Rig']
assert mesh.parent==rig
assert len(mesh.modifiers)==1 and mesh.modifiers[0].object==rig
assert len(mesh.data.materials)==6
assert len(rig.data.bones)==20
assert all(len(v.groups)>0 for v in mesh.data.vertices)
assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in mesh.data.vertices)
assert max(len(v.groups) for v in mesh.data.vertices)<=2
assert all(rig.data.bones.get(g.name) for g in mesh.vertex_groups)
assert not mesh.animation_data and not rig.animation_data
assert abs(min(v.co.z for v in mesh.data.vertices))<1e-5
assert 1.7<max(v.co.z for v in mesh.data.vertices)<1.9
assert all(n.type!='TEX_IMAGE' for m in mesh.data.materials for n in m.node_tree.nodes)

def reset():
    for p in rig.pose.bones:
        p.location=(0,0,0); p.rotation_euler=(0,0,0); p.scale=(1,1,1)
    bpy.context.view_layer.update()

def coords():
    ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me=ev.to_mesh()
    arr=[v.co.copy() for v in me.vertices]
    ev.to_mesh_clear()
    return arr

reset(); base=coords()
cases={
    'arm_flex':{'UpperArm.L':(math.radians(-35),0,0),'Forearm.L':(math.radians(-80),0,0),'Clavicle.L':(0,0,math.radians(-10)), 'Hand.L':(0,math.radians(15),0)},
    'leg_flex':{'Thigh.R':(math.radians(-40),0,0),'Shin.R':(math.radians(85),0,0),'Foot.R':(math.radians(-20),0,0)},
    'torso_twist':{'Spine':(math.radians(12),math.radians(10),0),'Chest':(0,math.radians(18),math.radians(8))},
    'head_turn':{'Neck':(math.radians(8),0,0),'Head':(0,math.radians(30),math.radians(8))},
}
stats={}
try:
    for name,pose in cases.items():
        reset()
        for b,euler in pose.items(): rig.pose.bones[b].rotation_euler=euler
        bpy.context.view_layer.update()
        current=coords()
        assert all(math.isfinite(x) for v in current for x in v)
        distances=[(a-b).length for a,b in zip(current,base)]
        assert max(distances)>.01
        ratios=[]
        for e in mesh.data.edges:
            i,j=e.vertices
            old=(base[i]-base[j]).length
            if old>.005: ratios.append((current[i]-current[j]).length/old)
        stats[name]={'max_vertex_motion_m':round(max(distances),4),'moved_vertices':sum(d>.0001 for d in distances),'max_edge_stretch':round(max(ratios),3)}
        assert max(ratios)<2.0, (name,max(ratios))
    reset()
    for pose in cases.values():
        for b,euler in pose.items(): rig.pose.bones[b].rotation_euler=euler
    bpy.context.view_layer.update()
    # Optional combined pose for visual checks. Never creates keyframes or actions.
    stats['weight_audit']={'unweighted':0,'unnormalized':0,'max_influences':2,'method':'Explicit region weights with smooth two-bone transitions; rigid face, hair, palms and boots; no automatic cross-limb weights.'}
    (OUT/'deformation_report.json').write_text(json.dumps(stats,indent=2))
except Exception:
    reset()
    raise
result=stats
if not globals().get('PLAYER_KEEP_TEST_POSE', False):
    reset()
