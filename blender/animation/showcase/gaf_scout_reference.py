"""Preview existing showcase Actions on the rigid Scout character."""
from itertools import product
import math

import bpy
from bpy.app.handlers import persistent
from bpy.props import StringProperty
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

TAG = "gaf_scout_reference"
SCENE = "Scout - Reference Character"
PREFIX = "Scout | Reference | "
COLLECTION = "Scout — Reference Character"
DRIVER = PREFIX + "Motion Source"
RIG = PREFIX + "Rig"
CAMERAS = {
    "FRONT": "Front", "THREE_QUARTER": "Three-quarter", "RIGHT": "Right", "BACK": "Back",
    "LEFT": "Left", "FACE": "Face", "CHEST": "Clothing", "BOOTS": "Boots", "REAR_DETAIL": "Cloak detail",
}
CLIPS = {
    "Idle": ("Idle_Expressive_Test_v3", 1, 240, True),
    "Walk": ("Walk_Expressive_Test", 1, 36, True),
    "Run": ("Run_Expressive_v3_Test", 1, 20, True),
    "Jump": ("Full_Jump_Expressive_Test", 1, 93, False),
    "Combat": ("Sword_Attack1_Original_v001", 1, 19, False),
}
SIDE = ("L","R")
UNIT = Vector((1.0,1.0,1.0))
FITTERS = {}
ARM_FITS = sorted(product(range(0,19), (0,1,-1,2,-2), (0,2,4,6,9,12)),
                  key=lambda option: .006*option[0]+.018*abs(option[1])+.0043*option[2])

def smoothstep(value):
    value = min(1.0,max(0.0,value))
    return value*value*(3 - 2*value)

def fit_cape_vertex(co, side):
    x,y,z=co
    sign=1 if side=="L" else -1
    wing=smoothstep(.54 + sign*x/.40)
    # The waist stays seated underneath the belt. The lower cloth follows leg clearance.
    freedom=smoothstep((.974-z)/.315)
    side_fold=smoothstep((sign*x-.097)/.142)*smoothstep((1.25-z)/.32)
    return Vector((x+sign*(.040*wing*freedom+.146*side_fold),
                   y+.45*wing*freedom+.17*side_fold,
                   z+.048*wing*freedom))

class MeshProbe:
    def __init__(self, obj):
        self.bone=obj.parent_bone
        self.vertices=[v.co.copy() for v in obj.data.vertices]
        obj.data.calc_loop_triangles()
        self.triangles=[tuple(triangle.vertices) for triangle in obj.data.loop_triangles]

    def tree(self, transform, vertices=None):
        points = self.vertices if vertices is None else vertices
        return BVHTree.FromPolygons([transform @ vertex for vertex in points], self.triangles,all_triangles=True)

class ScoutFitter:
    def __init__(self, scene):
        self.scout=scene.objects[RIG]
        self.driver=scene.objects[DRIVER]
        self.rig_bones=list(self.scout.pose.bones)
        self.inv_rest={bone.name:bone.bone.matrix_local.inverted() for bone in self.rig_bones}
        self.cape=scene.objects[PREFIX+"One-piece cloak"]
        self.hem=self.cape.data.shape_keys.key_blocks
        self.cape_probe=MeshProbe(self.cape)
        self.cape_offsets={
            side:[point.co - base for point,base in zip(self.hem["Follow " + side].data,self.cape_probe.vertices)]
            for side in SIDE
        }
        self.hood=MeshProbe(scene.objects[PREFIX+"Hood shell and opening"])
        self.arms={
            side:[MeshProbe(scene.objects[PREFIX+part+" "+side]) for part in ("Sleeve mantle","Shoulder yoke")]
            for side in SIDE
        }
        self.legs={side:MeshProbe(scene.objects[PREFIX+"Trouser leg "+side]) for side in SIDE}
        self.soles={side:MeshProbe(scene.objects[PREFIX+"Boot sole "+side]) for side in SIDE}

    def world(self, probe, poses):
        bone=probe.bone
        return poses[bone] @ self.inv_rest[bone]

    def rigid_poses(self,depsgraph):
        source=self.driver.evaluated_get(depsgraph)
        return {
            bone.name:Matrix.LocRotScale(bone.matrix.translation,
                                        bone.matrix.to_quaternion(),UNIT)
            for bone in source.pose.bones
        }

    def fit_arms(self, poses):
        hood=self.hood.tree(self.world(self.hood,poses))
        residual={}
        max_offset=0.0
        for side in SIDE:
            sign=1 if side=="L" else -1
            name="UpperArm."+side
            initial=poses[name].copy()
            selected=None
            for offset_step, depth_step, swivel in ARM_FITS:
                offset=.006*offset_step
                depth=.0175*depth_step
                spin=Quaternion((0,1,0),math.radians(-sign*swivel))
                candidate=Matrix.LocRotScale(initial.translation,spin@initial.to_quaternion(),UNIT)
                candidate.translation.x += sign*offset
                candidate.translation.y += depth
                poses[name]=candidate
                if not any(hood.overlap(probe.tree(self.world(probe,poses))) for probe in self.arms[side]):
                    selected=(math.hypot(offset,depth),candidate)
                    break
            residual[side]=selected is None
            if selected is not None:
                max_offset=max(max_offset,selected[0])
                poses[name]=selected[1]
            else:
                poses[name]=initial
        return residual, max_offset

    def cape_contact(self,poses,legs,weights):
        if any(weights.values()):
            vertices=[p+weights["L"]*a+weights["R"]*b for p,a,b in
                      zip(self.cape_probe.vertices,self.cape_offsets["L"],self.cape_offsets["R"])]
        else:
            vertices=None
        tree=self.cape_probe.tree(self.world(self.cape_probe,poses),vertices)
        return {side:bool(tree.overlap(legs[side])) for side in SIDE}

    def fit_cape(self,poses):
        legs={side:probe.tree(self.world(probe,poses)) for side,probe in self.legs.items()}
        weights={side:0.0 for side in SIDE}
        contact=self.cape_contact(poses,legs,weights)
        while any(contact[side] and weights[side]<1.0 for side in SIDE):
            for side in SIDE:
                if contact[side]:
                    weights[side]=min(1.0,weights[side]+.10)
            contact=self.cape_contact(poses,legs,weights)
        for side,amount in weights.items():
            self.hem["Follow "+side].value=amount
        return contact,max(weights.values())

    def solve(self,depsgraph):
        poses=self.rigid_poses(depsgraph)
        arm_contacts, shoulder_offset=self.fit_arms(poses)
        cape_contacts,cape_weight=self.fit_cape(poses)
        # The clips are in-place. Keep the Scout's deeper boot toe out of the review floor.
        lowest=min((self.world(probe,poses) @ point).z
                   for probe in self.soles.values() for point in probe.vertices)
        lift=max(0.0,-lowest)
        if lift:
            for matrix in poses.values():
                matrix.translation.z += lift
        for bone in self.rig_bones:
            rest=bone.bone.matrix_local
            target=poses[bone.name]
            if bone.parent:
                bone.matrix_basis=bone.bone.convert_local_to_pose(
                    target,rest,parent_matrix=poses[bone.parent.name],
                    parent_matrix_local=bone.parent.bone.matrix_local,invert=True)
            else:
                bone.matrix_basis=bone.bone.convert_local_to_pose(target,rest,invert=True)
        return {
            "sleeve contacts":sum(arm_contacts.values()), "cloak contacts":sum(cape_contacts.values()),
            "shoulder offset":shoulder_offset, "cape weight":cape_weight,"floor lift":lift,
        }

def frame_view(scene,motion):
    hero=scene.objects[PREFIX+"Three-quarter"].data
    hero.lens=75
    if motion:
        hero.lens=54 if scene["Scout playback"]=="Jump" else 62
    for name in ("Front","Back","Right","Left"):
        camera=scene.objects[PREFIX+name].data
        camera.ortho_scale=2.09
        if motion:
            camera.ortho_scale=2.65 if scene["Scout playback"]=="Jump" else 2.48

def reset(scene):
    driver=scene.objects[DRIVER]
    driver.animation_data_clear()
    for obj in (scene.objects[RIG],driver):
        for bone in obj.pose.bones:
            bone.matrix_basis=Matrix.Identity(4)
    hem=scene.objects[PREFIX+"One-piece cloak"].data.shape_keys.key_blocks
    for side in SIDE:
        hem["Follow "+side].value=0.0
    scene["Scout playback"]="Rest"
    frame_view(scene,False)
    FITTERS.pop(scene.as_pointer(),None)
    scene.frame_start=1
    scene.frame_end=60
    scene.frame_set(1)

def start(scene,label):
    if label=="Rest":
        reset(scene)
        return
    name,start_frame,end_frame,loop=CLIPS[label]
    action=scene["Scout clip actions"][label]
    if action.name!=name or len(action.slots)!=1:
        raise ValueError(f"Scout preview source is unavailable: {name}")
    cap=int(action.frame_range[1])
    driver=scene.objects[DRIVER]
    driver.animation_data_clear()
    for bone in driver.pose.bones:
        bone.matrix_basis=Matrix.Identity(4)
    hem=scene.objects[PREFIX+"One-piece cloak"].data.shape_keys.key_blocks
    if "Hero sweep" in hem:
        hem["Hero sweep"].value=0.0
    anim=driver.animation_data_create()
    anim.action=action
    anim.action_slot=action.slots[0]
    scene["Scout playback"]=label
    frame_view(scene,True)
    FITTERS.pop(scene.as_pointer(),None)
    scene.render.fps=30
    scene.render.fps_base=1.0
    scene.frame_start=start_frame
    scene.frame_end=min(end_frame,cap-1 if loop else cap)
    scene.gaf_loop=loop
    scene.frame_set(scene.frame_start)

@persistent
def on_frame(scene, depsgraph):
    if not scene.get(TAG) or scene.get("Scout playback","Rest")=="Rest" or depsgraph is None:
        return
    pointer=scene.as_pointer()
    fitter=FITTERS.get(pointer)
    if fitter is None:
        fitter=ScoutFitter(scene)
        FITTERS[pointer]=fitter
    fitter.solve(depsgraph)

@persistent
def release_caches(_):
    FITTERS.clear()

class GAF_OT_open_scout_reference(bpy.types.Operator):
    bl_idname="gaf.open_scout_reference"
    bl_label="Scout Reference Character"

    def execute(self,context):
        scene=bpy.data.scenes.get(SCENE)
        if scene is None or not scene.get(TAG):
            return {'CANCELLED'}
        from gaf_animation_library import stop_playback, view
        stop_playback(context)
        context.window.scene=scene
        view(scene,"THREE_QUARTER")
        return {'FINISHED'}

class GAF_OT_set_scout_playback(bpy.types.Operator):
    bl_idname="gaf.set_scout_playback"
    bl_label="Set Scout Preview Clip"
    clip: StringProperty()

    def execute(self,context):
        from gaf_animation_library import stop_playback
        if not context.scene.get(TAG):
            return {'CANCELLED'}
        try:
            stop_playback(context)
            start(context.scene,self.clip)
        except (KeyError,ValueError,RuntimeError) as error:
            self.report({'ERROR'},str(error))
            return {'CANCELLED'}
        return {'FINISHED'}

def draw_preview(layout,scene):
    controls=layout.box()
    controls.label(text="Scout",icon="OUTLINER_OB_ARMATURE")
    current=scene.get("Scout playback","Rest")
    for group in (("Rest","Idle","Walk"),("Run","Jump","Combat")):
        row=controls.row(align=True)
        for label in group:
            row.operator("gaf.set_scout_playback",text=label,depress=(label==current)).clip=label
    if current=="Rest":
        cape=scene.objects[PREFIX+"One-piece cloak"]
        controls.prop(cape.data.shape_keys.key_blocks["Hero sweep"],"value",text="Hero cloak sweep",slider=True)
    else:
        row=controls.row(align=True)
        row.operator("gaf.play_pause",icon="PLAY")
        row.operator("gaf.restart",icon="REW")
        controls.prop(scene,"gaf_loop",text="Loop playback")
    for group in (("FRONT","THREE_QUARTER","BACK"),("LEFT","RIGHT","FACE"),
                  ("CHEST","BOOTS","REAR_DETAIL")):
        row=controls.row(align=True)
        for key in group:
            row.operator("gaf.view",text=CAMERAS[key]).direction=key
    layout.operator("gaf.return_library",icon="BACK")

CLASSES=(GAF_OT_open_scout_reference,GAF_OT_set_scout_playback)

def register_handlers():
    bpy.app.handlers.frame_change_post.append(on_frame)
    bpy.app.handlers.load_post.append(release_caches)

def unregister_handlers():
    for handlers,fn in ((bpy.app.handlers.frame_change_post,on_frame),(bpy.app.handlers.load_post,release_caches)):
        if fn in handlers:
            handlers.remove(fn)
    FITTERS.clear()


