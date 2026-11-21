"""Build a fresh, rigged Forager from the no-backpack turnaround."""
from pathlib import Path
from math import radians,cos,sin
import sys

import bpy
from mathutils import Matrix,Quaternion,Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import forms
from forms import U,block,collection,material
from headwear import make_head
from garments import make_outfit
from details import torso_props,staff_and_lamp

source=Path(sys.argv[-3])
out=Path(sys.argv[-2])
quality=sys.argv[-1]
full=quality=="final"
out.mkdir(parents=True,exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.name="The Forager"
scene.unit_settings.system="METRIC"
scene["Design reference"]="The Forager | turnaround without backpack"
scene["Character"]="New geometry and pixel paint fitted to the supplied reference"
character=collection("THE FORAGER",scene.collection)
head=collection("01 · Hood, face and braid",character)
chest=collection("02 · Shirt, scarf and belts",character)
cloak=collection("03 · Shoulders and long cape",character)
limbs=collection("04 · Arms, trousers and boots",character)
gear=collection("05 · Hip bag and herbs",character)
prop=collection("Hero props · Lantern and travel staff",scene.collection)
studio=collection("Studio and review cameras",scene.collection)

with bpy.data.libraries.load(str(source),link=False) as (src,dst):
    assert "Showcase_Player_Rig" in src.objects
    dst.objects=["Showcase_Player_Rig"]
rig=dst.objects[0]
character.objects.link(rig)
rig.name="The Forager | 13-bone rig"
rig.parent=None
rig.animation_data_clear()
for c in list(rig.constraints):
    rig.constraints.remove(c)
for bone in rig.pose.bones:
    for c in list(bone.constraints):
        bone.constraints.remove(c)
    bone.matrix_basis=Matrix.Identity(4)
    bone.rotation_mode="QUATERNION"
rig.matrix_world=Matrix.Identity(4)
rig.hide_set(True)
rig.show_in_front=True
forms.RIG=rig

for name,rough,metal in (
    ("moss",.91,0),("mossDark",.94,0),("lining",.95,0),("gold",.87,0),
    ("rust",.91,0),("hair",.78,0),("leather",.86,0),("warmLeather",.84,0),
    ("boot",.86,0),("coal",.92,0),("linen",.96,0),("cream",.92,0),
    ("skin",.80,0),("face",.79,0),("iron",.43,1),("leaf",.91,0),
    ("purple",.89,0),("wood",.9,0),("stone",.76,0),
):
    material(name,rough,metal)
material("amber",.42,0,(.98,.26,.029),1.25)
material("flame",.45,0,(1.0,.50,.075),2.05)
material("stage",.94,0,(.027,.019,.026),.44)

make_head(head,chest)
make_outfit(chest,cloak,limbs)
torso_props(gear)

def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()

def camera(name,yaw,pitch,target,scale):
    data=bpy.data.cameras.new(name)
    data.type="ORTHO"
    data.ortho_scale=scale
    data.clip_end=350
    cam=bpy.data.objects.new(name,data)
    studio.objects.link(cam)
    a,b=radians(yaw),radians(pitch)
    cam.location=Vector(target)+6*Vector((sin(a)*cos(b),-cos(a)*cos(b),sin(b)))
    aim(cam,target)
    return cam

cams={
    "Front":camera("Front",0,1.0,(0,0,.91),2.08),
    "Hero":camera("Hero",-39,5.1,(.09,-.017,.90),2.11),
    "Right":camera("Right",-90,1.1,(0,-.035,.91),2.06),
    "Back":camera("Back",180,1.0,(0,0,.91),2.08),
    "Left":camera("Left",90,1.1,(0,-.035,.91),2.06),
}
marks={}
for i,(name,cam) in enumerate(cams.items(),1):
    mark=scene.timeline_markers.new(name,frame=i)
    mark.camera=cam
    marks[name]=mark
scene.frame_start=1
scene.frame_end=5

def axis_delta(bone,axis,angle):
    rest=bone.bone.matrix_local.to_3x3()
    return Quaternion((rest.inverted()@Vector(axis)).normalized(),radians(angle))

affected=("Head","Chest","ForeArm.L","Leg.R","Leg.L")
for key,mark in marks.items():
    scene.frame_set(mark.frame)
    for name in affected:
        bone=rig.pose.bones[name]
        bone.matrix_basis=Matrix.Identity(4)
        if key=="Hero":
            if name=="Head":
                view=cams["Hero"].matrix_world.to_quaternion()@Vector((0,0,-1))
                bone.rotation_quaternion=axis_delta(bone,view,11.5)
            elif name=="Chest":
                view=cams["Hero"].matrix_world.to_quaternion()@Vector((0,0,-1))
                bone.rotation_quaternion=axis_delta(bone,view,-2.3)
            elif name=="ForeArm.L":
                bone.rotation_quaternion=axis_delta(bone,(1,0,0),-61)
            else:
                side=-1 if name.endswith(".R") else 1
                basis=bone.bone.matrix_local.to_3x3().inverted()
                bone.location=basis@Vector((side*.024,-side*.026,.012))
                bone.rotation_quaternion=axis_delta(bone,(0,1,0),-side*5.2) @ axis_delta(bone,(0,0,1),side*5.5)
                bpy.context.view_layer.update()
                sole=scene.objects[("R" if side<0 else "L")+" · heavy sole"]
                low=min((sole.matrix_world@v.co).z for v in sole.data.vertices)
                bone.location+=basis@Vector((0,0,-low))
        bone.keyframe_insert(data_path="location",frame=mark.frame)
        bone.keyframe_insert(data_path="rotation_quaternion",frame=mark.frame)
rig.animation_data.action.name="Forager · still review poses"
scene.frame_set(marks["Hero"].frame)
bpy.context.view_layer.update()

mark_hand=scene.objects["L · hand and fingers"]
hand=mark_hand.matrix_world@(Vector((77,-7,130))*U)
grip=tuple(hand/U)
lamp_location=staff_and_lamp(prop,(grip[0],grip[1]-2.0,grip[2]))

world=bpy.data.worlds.new("Studio · soft purple ambient")
world.use_nodes=True
world.node_tree.nodes.get("Background").inputs[0].default_value=(.24,.19,.22,1)
world.node_tree.nodes.get("Background").inputs[1].default_value=.30
scene.world=world
block("Studio · floor",(0,0,-1.26),(100000,100000,2.43),"stage",studio,None,0)

def area(name,pos,target,power,color,size):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=power
    data.color=color
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=pos
    aim(obj,target)
    return obj

area("Key · warm from above",(-2.3,-3.2,4.2),(0,0,1.08),340,(1,.83,.68),1.78)
area("Fill · eye and cloth",(.9,-3.85,2.0),(0,0,1.34),68,(1,.90,.80),2.32)
area("Rim · warm cloth edge",(-1.6,1.6,3.24),(0,0,1.24),285,(1,.77,.59),1.34)
area("Far fill",(2.4,1.1,2.8),(0,0,1.08),102,(.83,.85,1),2.0)
lamp=bpy.data.lights.new("Lantern · amber bounce","POINT")
lamp.energy=7.1
lamp.color=(1,.51,.21)
lamp.shadow_soft_size=.07
glow=bpy.data.objects.new(lamp.name,lamp)
prop.objects.link(glow)
glow.location=Vector(lamp_location)*U

for obj in prop.objects:
    for name,mark in marks.items():
        obj.hide_render=name!="Hero"
        obj.hide_viewport=name!="Hero"
        obj.keyframe_insert(data_path="hide_render",frame=mark.frame)
        obj.keyframe_insert(data_path="hide_viewport",frame=mark.frame)

scene.render.engine="CYCLES"
scene.cycles.samples=52 if full else 20
scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGB"
scene.render.film_transparent=False
scene.render.threads_mode="FIXED"
scene.render.threads=12
scene.view_settings.view_transform="AgX"
scene.view_settings.look="AgX - Medium High Contrast"
scene.view_settings.exposure=.06
scene.render.resolution_x=900 if full else 540
scene.render.resolution_y=1180 if full else 710

for view in (("Hero","Front","Right","Back","Left") if full else ("Hero","Front","Back")):
    mark=marks[view]
    scene.frame_set(mark.frame)
    scene.camera=mark.camera
    scene.render.filepath=str(out/f"{view.lower()}.png")
    bpy.ops.render.render(write_still=True)

scene.frame_set(marks["Hero"].frame)
scene.camera=cams["Hero"]
scene.render.filepath="//The Forager - Hero.png"
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            sp=area.spaces.active
            sp.region_3d.view_perspective="CAMERA"
            sp.shading.color_type="TEXTURE"
            sp.overlay.show_overlays=False
for ob in bpy.context.selected_objects:
    ob.select_set(False)
bpy.data.orphans_purge(do_recursive=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"The Forager.blend"),compress=True,relative_remap=False)


