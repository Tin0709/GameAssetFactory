"""Test action binding and mesh clearance on the candidate without saving either input."""
from pathlib import Path
import json,math,sys
import bpy
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

source=Path(sys.argv[-2]).resolve()
report=Path(sys.argv[-1]).resolve()
scene=bpy.context.scene
prefix="Scout Canon | "
rig=scene.objects[prefix+"Rig"]
body={"UpperArm.R":"R Arm","UpperArm.L":"L Arm","Leg.R":"R leg","Leg.L":"L leg"}
for bone,part in body.items():
    assert scene.objects[prefix+part].parent_bone==bone
for clip in bpy.data.shape_keys:
    for key in clip.key_blocks:
        if key.name == 'Hero drape':
            key.driver_remove('value')
            key.value = 0
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis=Matrix.Identity(4)
scene.frame_set(1)
dep=bpy.context.evaluated_depsgraph_get()
base={k:rig.evaluated_get(dep).pose.bones[k].matrix.copy() for k in body}
reviews=source.parent.parent/"reviews/player_animation_library_v1"
specs=[
 ("Idle",reviews/"idle_expressive_test_v3/idle_expressive_v3_review.blend","Idle_Expressive_Test_v3"),
 ("Walk",reviews/"walk_expressive_test/walk_expressive_review.blend","Walk_Expressive_Test"),
 ("Run",reviews/"run_expressive_v3_test/run_expressive_v3_review.blend","Run_Expressive_v3_Test"),
 ("Jump",reviews/"full_jump_expressive_test/full_jump_expressive_review.blend","Full_Jump_Expressive_Test"),
]
pairs=[("R trouser","Long cloak with tapered supporting folds"),
       ("L trouser","Long cloak with tapered supporting folds"),
       ("R Glove","Inner tunic"),("L Glove","Inner tunic"),
       ("R outsole","L outsole")]
def part_tree(name):
    ob=scene.objects[prefix+name].evaluated_get(dep)
    mesh=ob.data
    mesh.calc_loop_triangles()
    return BVHTree.FromPolygons([ob.matrix_world@v.co for v in mesh.vertices],
                                [tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True)
results={}
for label,file,name in specs:
    with bpy.data.libraries.load(str(file),link=True) as (src,dst):
        assert name in src.actions
        dst.actions=[name]
    action=dst.actions[0]
    slot=action.slots[0]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    assert rig.path_resolve(curve.data_path) is not None,curve.data_path
    for bone in rig.pose.bones:
        bone.matrix_basis=Matrix.Identity(4)
    animation=rig.animation_data_create()
    animation.action=action
    animation.action_slot=slot
    measured=dict.fromkeys(body,0.0)
    deviation=0
    contact={f"{a} / {b}":0 for a,b in pairs}
    ticks=list(range(math.ceil(action.frame_range[0]),math.floor(action.frame_range[1])+1))
    for tick in ticks:
        scene.frame_set(tick)
        eval_rig=rig.evaluated_get(dep)
        for k,part in body.items():
            mat=scene.objects[prefix+part].evaluated_get(dep).matrix_world.to_3x3()
            orth=mat.transposed()@mat-Matrix.Identity(3)
            deviation=max(deviation,max(abs(v) for row in orth for v in row))
            delta=eval_rig.pose.bones[k].matrix-base[k]
            measured[k]=max(measured[k],max(abs(v) for row in delta for v in row))
        for a,b in pairs:
            contact[f"{a} / {b}"]+=bool(part_tree(a).overlap(part_tree(b)))
    assert max(measured.values())>.01 and deviation<.001,(name,measured,deviation)
    results[label]=dict(action=name,samples=len(ticks),max_rigidity_error=deviation,intersection_frames=contact)
    rig.animation_data_clear()
report.write_text(json.dumps(results,indent=2),encoding="utf8")
print(json.dumps(results))


