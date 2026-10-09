"""Original stepped-petal periwinkle flowers. Run in the target live Blender file."""
from pathlib import Path
import importlib.util
import json
import math
import bpy
from mathutils import Vector, Matrix

HERE=Path(__file__).resolve().parent
OUT=HERE/'.validation'/'periwinkle_flowers_v1'
NAME='ENV_PeriwinkleFlowerPatch_08m_V1'
HORIZONTAL_SCALE=1.5

def audit_module():
    spec=importlib.util.spec_from_file_location('periwinkle_preservation',HERE/'flower_preservation.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def create(evidence_suffix=''):
    assert not bpy.app.background
    assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
    assert bpy.context.mode=='OBJECT'
    assert NAME not in bpy.data.objects, 'Preserve an existing study rather than overwrite.'
    OUT.mkdir(parents=True,exist_ok=True)
    backup=OUT/('live_before_periwinkle_flowers'+evidence_suffix+'.blend')
    assert not backup.exists()
    audit=audit_module()
    baseline=audit.snapshot()
    bpy.app.driver_namespace['periwinkle_baseline']=baseline
    (OUT/('before_snapshot'+evidence_suffix+'.json')).write_text(json.dumps(baseline,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True)
    assert not audit.compare(baseline)

    scene=bpy.context.scene
    assets=bpy.data.collections.new('FLOWERS_Periwinkle_08Block_V1')
    review=bpy.data.collections.new('REVIEW_Periwinkle_Flowers_V1')
    scene.collection.children.link(assets)
    scene.collection.children.link(review)
    vertices=[];faces=[];face_meta=[]
    def face(points,rgb,index,part,mask,pivot,root):
        start=len(vertices)
        vertices.extend(tuple(p) for p in points)
        faces.append(tuple(range(start,start+len(points))))
        masks=[mask]*len(points) if isinstance(mask,(int,float)) else mask
        face_meta.append((rgb,index,part,masks,pivot,root))

    # Original clump enlarged horizontally; preserve exact 0.8m total height.
    stems=[(-.27,-.24,.58,.035,-.020),(.03,-.30,.68,-.025,.030),
           (.28,-.15,.62,-.020,.025),(-.30,.13,.73,.040,-.018),
           (-.04,.05,.79,-.018,.016),(.26,.23,.66,-.025,-.030),
           (.02,.31,.76,.028,-.025)]
    petals=[(80,99,187),(108,88,181),(94,111,200),(121,103,197)]
    for index,(rx,ry,height,lx,ly) in enumerate(stems):
        root=(rx,ry)
        at=lambda t:Vector((rx+lx*t,ry+ly*t,height*t))
        phi=index*1.73
        rings=[0,.28,.63,1]
        for plane in [phi,phi+math.pi/2]:
            width=Vector((math.cos(plane),math.sin(plane),0))*.008
            for a,b in zip(rings,rings[1:]):
                rgb=(92,124,66) if a<.3 else (113,143,79)
                face([at(a)-width,at(a)+width,at(b)+width,at(b)-width],rgb,index,0,[a,a,b,b],height,root)
        for leaf,t in enumerate([.36,.58]):
            angle=phi+leaf*math.pi
            axis=Vector((math.cos(angle),math.sin(angle),.35)).normalized()
            side=Vector((-math.sin(angle),math.cos(angle),0))
            base=at(t)
            face([base,base+axis*.055-side*.023,base+axis*.115-side*.018,
                  base+axis*.115+side*.018,base+axis*.055+side*.023],
                 (113,148,80) if leaf else (102,136,71),index,3,t,height,root)
        # Eight stepped, blunt petal tongues: angular cornflower-like outline.
        center=at(1)
        tilt=Matrix.Rotation(math.radians([-8,10,-12,7,4,-6,11][index]),3,'X')
        spin=index*.47
        shape=[(.022,-.017),(.074,-.030),(.074,-.019),(.123,-.019),
               (.123,.019),(.074,.019),(.074,.030),(.022,.017)]
        size=[.91,1,.88,1.04,1.06,.93,1.0][index]
        for petal in range(8):
            angle=spin+petal*math.pi/4
            turn=Matrix.Rotation(angle,3,'Z')
            points=[center+tilt@(turn@Vector((x*size,y*size,0))) for x,y in shape]
            face(points,petals[(index+petal%3)%len(petals)],index,1,1,height,root)
        points=[center+tilt@Vector((math.cos(i*math.pi/4)*.033,
                                   math.sin(i*math.pi/4)*.033,.001)) for i in range(8)]
        face(points,(79,76,148),index,2,1,height,root)

    # Exactly 4/5 of a 1m block, including the highest tilted petal tip.
    z_scale=.8/max(p[2] for p in vertices)
    vertices=[(x*HORIZONTAL_SCALE,y*HORIZONTAL_SCALE,z*z_scale) for x,y,z in vertices]
    mesh=bpy.data.meshes.new(NAME+'_PlanarMesh')
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    uv=mesh.uv_layers.new(name='UV_Stem_Height')
    roots=mesh.uv_layers.new(name='UV_Flower_Root')
    ids=mesh.attributes.new(name='flower_index',type='INT',domain='FACE')
    parts=mesh.attributes.new(name='flower_part',type='INT',domain='FACE')
    for poly,meta in zip(mesh.polygons,face_meta):
        rgb,index,part,masks,pivot,root=meta
        ids.data[poly.index].value=index
        parts.data[poly.index].value=part
        for corner,loop in enumerate(poly.loop_indices):
            colors.data[loop].color_srgb=tuple(c/255 for c in rgb)+(1,)
            uv.data[loop].uv=(masks[corner],pivot*z_scale)
            roots.data[loop].uv=(root[0]*HORIZONTAL_SCALE+.5,root[1]*HORIZONTAL_SCALE+.5)
    mesh.color_attributes.active_color=colors
    mesh.materials.append(bpy.data.materials['MAT_WhiteFlower_V1_LinearVertexAlbedo'])
    obj=bpy.data.objects.new(NAME,mesh)
    assets.objects.link(obj)
    obj.location=(23,0,1)
    obj['placement_footprint_m']=[1.5,1.5]
    obj['horizontal_scale_from_first_study']=1.5
    obj['height_m']=.8
    obj['flowers']=7
    obj['authoring_status']='Blender-only V1; awaiting human review'
    obj['reference']='User supplied 2026-10-09 periwinkle flowers; original geometry/palette'
    obj.asset_mark()
    obj.asset_data.description='Seven periwinkle/lavender flowers, 0.8m high; enlarged 1.5x horizontally.'
    block=bpy.data.objects['ENV_GrassBlock_DI_V3'].copy()
    block.name='REVIEW_Periwinkle_1m_Platform'
    block.location=(23,0,0)
    block['display_only']=True
    review.objects.link(block)
    for suffix,body,y,size in [('Title','PERIWINKLE FLOWERS',-.84,.12),
                                ('Size','0.8 BLOCK HIGH / 1.5x WIDER',-1.07,.070)]:
        font=bpy.data.curves.new('Periwinkle_'+suffix+'_Font','FONT')
        font.body=body;font.align_x='CENTER';font.size=size
        font.materials.append(bpy.data.materials['Type_Cream'])
        label=bpy.data.objects.new('REVIEW_Periwinkle_'+suffix,font)
        label.location=(23,y,.012)
        review.objects.link(label)
    receivers=bpy.data.collections.new('LIGHT_RECEIVERS_Periwinkle_V1')
    for target in [obj,*review.objects]: receivers.objects.link(target)
    for name,position,power,size in [('Key',(21.5,-3,5),480,4),('Fill',(25,2,4),240,3)]:
        data=bpy.data.lights.new('Periwinkle_'+name+'_Data','AREA')
        data.energy=power;data.shape='DISK';data.size=size
        data.color=(1,.94,.85) if name=='Key' else (.80,.90,1)
        lamp=bpy.data.objects.new('Periwinkle_'+name,data)
        review.objects.link(lamp);lamp.location=position
        lamp.rotation_euler=(Vector((23,0,1.25))-lamp.location).to_track_quat('-Z','Y').to_euler()
        lamp.light_linking.receiver_collection=receivers
    data=bpy.data.cameras.new('CAM_Periwinkle_V1_Data')
    camera=bpy.data.objects.new('CAM_Periwinkle_V1',data)
    review.objects.link(camera)
    data.type='ORTHO';data.ortho_scale=3.05
    camera.location=(25.4,-4.2,3.8)
    camera.rotation_euler=(Vector((23,-.10,.95))-camera.location).to_track_quat('-Z','Y').to_euler()
    for old in bpy.context.selected_objects:old.select_set(False)
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    for window in bpy.context.window_manager.windows:
        if window.scene!=scene:continue
        for area in window.screen.areas:
            if area.type!='VIEW_3D':continue
            space=area.spaces.active
            space.use_local_camera=True;space.camera=camera
            space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=23
            space.shading.type='MATERIAL'
            space.shading.use_scene_lights=True;space.shading.use_scene_world=True
            space.overlay.show_overlays=False
    bpy.context.view_layer.update()
    errors=audit.compare(baseline)
    assert not errors,errors
    measurements=validate()
    measurements['old_data_changes']=errors
    measurements['backup']=str(backup)
    (OUT/'verification.json').write_text(json.dumps(measurements,indent=2))
    return measurements

def validate():
    obj=bpy.data.objects[NAME];mesh=obj.data
    coords=[v.co for v in mesh.vertices]
    assert abs(max(v.z for v in coords)-.8)<1e-6
    assert min(v.z for v in coords)==0
    assert all(abs(v.x)<=.75 and abs(v.y)<=.75 for v in coords)
    assert obj.scale==Vector((1,1,1))
    mesh.calc_loop_triangles()
    return {'object':obj.name,'flowers':7,'petals_per_head':8,'height_m':float(obj.dimensions.z),
            'dimensions_m':list(obj.dimensions),'triangles':len(mesh.loop_triangles),
            'location':list(obj.location),'source_file':bpy.data.filepath,
            'status':'AWAITING HUMAN REVIEW','scope':'Blender-only; no Godot integration'}

def render():
    scene=bpy.context.scene
    keep=set(bpy.data.collections['FLOWERS_Periwinkle_08Block_V1'].objects)|set(bpy.data.collections['REVIEW_Periwinkle_Flowers_V1'].objects)
    hidden=[(o,o.hide_render) for o in scene.objects if o not in keep and o.name!='Studio_Floor' and o.type not in {'LIGHT','CAMERA'}]
    saved=(scene.camera,scene.render.filepath,scene.render.resolution_x,scene.render.resolution_y,
           scene.render.resolution_percentage,scene.cycles.samples)
    try:
        for obj,_ in hidden:obj.hide_render=True
        scene.camera=bpy.data.objects['CAM_Periwinkle_V1']
        scene.render.resolution_x=1000;scene.render.resolution_y=1000
        scene.render.resolution_percentage=100;scene.cycles.samples=32
        scene.render.filepath=str(OUT/'periwinkle_review.png')
        bpy.ops.render.render(write_still=True)
    finally:
        for obj,value in hidden:obj.hide_render=value
        scene.camera,scene.render.filepath,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.cycles.samples=saved
    return {'image':str(OUT/'periwinkle_review.png')}
