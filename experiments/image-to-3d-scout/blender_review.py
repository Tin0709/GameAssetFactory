"""Review existing and generated assets in separate Blender files."""
import argparse
from pathlib import Path
import sys
from math import radians

import bpy
from mathutils import Vector, Matrix

def append_scene(path, name):
    with bpy.data.libraries.load(str(path)) as (src, dst):
        if name not in src.scenes:
            raise ValueError(f"Missing scene {name!r}: {path}")
        dst.scenes = [name]
    scene = dst.scenes[0]
    bpy.context.window.scene = scene
    return scene

def area(scene,label,position,power,hue,size):
    light=bpy.data.lights.new(label,"AREA")
    light.energy=power
    light.color=hue
    light.size=size
    obj=bpy.data.objects.new(label,light)
    scene.collection.objects.link(obj)
    obj.location=position
    obj.rotation_euler=(Vector((0,0,0.98))-obj.location).to_track_quat("-Z","Y").to_euler()

VIEWS = [("front",0,0.8),("hero",-32,2.0),("right",-88,1.5),("back",180,0.8),("left",88,1.5)]

def render_setup(scene):
    scene.render.engine="CYCLES"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=12
    scene.render.resolution_x=430
    scene.render.resolution_y=575
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"

def cameras(scene,focus=(0,0,0.9)):
    import math
    for view,yaw,pitch in VIEWS:
        a,b=radians(yaw),radians(pitch)
        data=bpy.data.cameras.new("CAM-"+view)
        data.type="ORTHO"
        data.ortho_scale=2.00
        obj=bpy.data.objects.new(data.name,data)
        scene.collection.objects.link(obj)
        obj.location=Vector(focus)+5*Vector((math.sin(a)*math.cos(b),-math.cos(a)*math.cos(b),math.sin(b)))
        obj.rotation_euler=(Vector(focus)-obj.location).to_track_quat("-Z","Y").to_euler()
        yield view,obj

def render(scene,camera_list,out):
    out.mkdir(parents=True,exist_ok=True)
    render_setup(scene)
    for frame,view,camera in camera_list:
        scene.frame_set(frame)
        scene.camera=camera
        scene.render.filepath=str(out / f"{view}.png")
        bpy.ops.render.render(write_still=True)
    scene.frame_set(camera_list[1][0])
    scene.camera=camera_list[1][2]

def generated(path,out,yaw):
    scene=bpy.context.scene
    old=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new=[o for o in scene.objects if o not in old and o.type=="MESH"]
    assert new
    # glTF import already maps Y-up into Blender Z-up.
    turn=Matrix.Rotation(radians(yaw),4,'Z')
    points=[turn@o.matrix_world@v.co for o in new for v in o.data.vertices]
    low=Vector(min(p[i] for p in points) for i in range(3))
    high=Vector(max(p[i] for p in points) for i in range(3))
    factor=1.80/(high.z-low.z)
    center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    normalize=Matrix.Scale(factor,4) @ Matrix.Translation(-center) @ turn
    material=bpy.data.materials.new("MAT-generation-clay")
    material.diffuse_color=(0.28,0.23,0.17,1)
    for obj in new:
        transform=normalize@obj.matrix_world
        obj.parent=None
        obj.matrix_world=transform
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for face in obj.data.polygons:
            face.use_smooth=True
    for obj in old:
        if obj.name in scene.objects:
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
    for label,position,power,hue,size in (
        ("LGT-Key",(-2.6,-2.4,4.1),295,(1,.84,.69),2),
        ("LGT-Fill",(2,-3.5,1.7),94,(1,.90,.86),2.8),
        ("LGT-Rim",(-1.6,2.3,3.1),390,(1,.75,.58),1.7),
        ("LGT-Rear",(1.9,2.5,2.4),85,(1,.91,.78),2.3),
    ):
        area(scene,label,position,power,hue,size)
    new_cameras=[(1,k,c) for k,c in cameras(scene)]
    render(scene,new_cameras,out)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"Review.blend"),compress=True)

def main(args):
    if args.source.suffix.lower()==".glb":
        generated(args.source,args.out,args.yaw)
        return
    scene=append_scene(args.source,args.scene)
    for obj in scene.objects:
        if obj.is_shadow_catcher:
            obj.hide_render=True
    table={m.name.casefold(): (m.frame,m.camera) for m in scene.timeline_markers if m.camera}
    render(scene,[(table[v][0],v,table[v][1]) for v,_,_ in VIEWS],args.out)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("source",type=Path)
    parser.add_argument("out",type=Path)
    parser.add_argument("--scene",default="Scout - Rogue Archer")
    parser.add_argument("--yaw",type=float,default=0)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    args.source = args.source.resolve()
    args.out = args.out.resolve()
    main(args)




