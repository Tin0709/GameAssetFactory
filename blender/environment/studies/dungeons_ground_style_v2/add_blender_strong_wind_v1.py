"""Foreground-only, additive strong-wind preview copies. Canonical meshes/export untouched."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Create source only in the connected foreground Blender window'
HERE=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
sys.path.insert(0,str(HERE))
from flower_preservation import compare
from blender_strong_wind_v1 import register,apply_preview_pose
from blender_strong_wind_audit import audit_wind
baseline=json.loads((HERE.parents[3]/'.validation/flower_patch_v1/before_strong_wind_fingerprints.json').read_text());assert not compare(baseline['data'])
assert not bpy.data.collections.get('REVIEW_Blender_Strong_Wind_V1')
collection=bpy.data.collections.new('REVIEW_Blender_Strong_Wind_V1');bpy.context.scene.collection.children.link(collection)
sources=[('ENV_WhiteFlowerPatch_1m_V1',17,'flowers'),('REVIEW_Original_Grass_V4',18.5,'grass'),('REVIEW_Meadow_Grass_V4_065',20,'grass'),('ENV_TallGoldenGrass_1m_V1',21.5,'gold')]
for name,x,kind in sources:
    source=bpy.data.objects[name];m=source.data.copy();m.name='REVIEW_WIND_'+name+'_IndependentMesh'
    o=source.copy();o.data=m;o.name='REVIEW_WIND_'+name;collection.objects.link(o);o.location=(x,6.2,1)
    o['display_only']=True;o['blender_only_strong_wind']=True;o['wind_kind']=kind;o['wind_reference_height']=max(v.co.z for v in m.vertices)
    if m.shape_keys:
        assert m.shape_keys!=source.data.shape_keys
        o.shape_key_clear()
    rest=m.attributes.new(name='wind_rest',type='FLOAT_VECTOR',domain='POINT');root=m.attributes.new(name='wind_root',type='FLOAT_VECTOR',domain='POINT')
    mask=m.attributes.new(name='wind_mask',type='FLOAT',domain='POINT');rigid=m.attributes.new(name='wind_rigid',type='BOOLEAN',domain='POINT');centers=m.attributes.new(name='wind_ring_center',type='FLOAT_VECTOR',domain='POINT')
    for v in m.vertices:rest.data[v.index].vector=v.co
    for p in m.polygons:
        for li in p.loop_indices:
            vi=m.loops[li].vertex_index
            if kind=='grass':t=m.color_attributes['GRASS_BEND_DATA'].data[vi].color[1];r=m.uv_layers['UV_Blade_Root'].data[li].uv;is_rigid=False
            else:
                t=m.uv_layers[0].data[li].uv.x;r=m.uv_layers[1].data[li].uv
                part=m.attributes['flower_part' if kind=='flowers' else 'part'].data[p.index].value;is_rigid=part!=0
            mask.data[vi].value=t;root.data[vi].vector=(r.x-.5,r.y-.5,0);rigid.data[vi].value=is_rigid
    groups={}
    for v in m.vertices:
        if not rigid.data[v.index].value:
            key=tuple(root.data[v.index].vector)+(mask.data[v.index].value,);groups.setdefault(key,[]).append(v.index)
    for indices in groups.values():
        center=sum((m.vertices[i].co for i in indices),Vector())/len(indices)
        for i in indices:centers.data[i].vector=center
    platform=bpy.data.objects['REVIEW_TallGolden_Platform_21'].copy();platform.name='REVIEW_WIND_Platform_'+str(x);collection.objects.link(platform);platform.location=(x,6.2,0)
label=bpy.data.objects['REVIEW_TallGolden_Actual_Height_Label'].copy();label.data=label.data.copy();label.name='REVIEW_WIND_Blender_Only_Label';collection.objects.link(label)
label.data.body='BLENDER ONLY / STRONG WIND\n4 SECOND LOOP / Timeline Play';label.location=(20.2,5.5,.08);label.data.size=.13
text=bpy.data.texts.new('RUN_Blender_Strong_Wind_V1');text.write("# Run this text after opening this study again to enable local wind.\nimport sys\nfrom pathlib import Path\nimport bpy\np=Path(bpy.data.filepath).parent\nsys.path.insert(0,str(p))\nfrom blender_strong_wind_v1 import register\nregister()\n")
register();report=audit_wind();apply_preview_pose(bpy.context.scene.frame_current)
scene=bpy.context.scene;scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=96
for selected in list(bpy.context.selected_objects):selected.select_set(False)
gold=bpy.data.objects['REVIEW_WIND_ENV_TallGoldenGrass_1m_V1'];gold.select_set(True);bpy.context.view_layer.objects.active=gold
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.overlay.show_overlays=False
        space.region_3d.view_location=(20.1,6.2,1.4);space.region_3d.view_distance=6.1;space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
(HERE.parents[3]/'.validation/flower_patch_v1/validation_blender_strong_wind_live.json').write_text(json.dumps(report,indent=2))
result={'status':'Four independent stronger wind previews created LIVE and saved; handler active','audit':report,'canonical_rest_exports':'unchanged','current_frame':scene.frame_current}
