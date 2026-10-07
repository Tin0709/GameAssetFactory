"""Apply the requested ~60% block height with unequal 0.48-0.70m leaves."""
import bpy
import json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'grass_block_wind_v3.blend').resolve()
main=bpy.data.scenes['ENV_Grass_Block_Wind_Review']
for name in ('ENV_Grass_Full_Surface_2D','DEMO_Grass_Wind_Plus_Player'):
    obj=bpy.data.objects[name]
    basis=obj.data.shape_keys.key_blocks['Basis']
    assert max(v.co.z for v in basis.data)<.4,'Height revision already applied; do not run it twice.'
    heights=[]
    for blade in range(49):
        start=blade*8
        original=basis.data[start+6].co.z
        new=.48+(original-.245)/(.38-.245)*.22
        ratio=new/original
        heights.append(new)
        for i in range(start,start+8):
            obj.data.vertices[i].co.z*=ratio
            for key in obj.data.shape_keys.key_blocks:
                key.data[i].co.z*=ratio
            c=list(obj.data.color_attributes['GRASS_BEND_DATA'].data[i].color)
            c[2]=new/.70
            obj.data.color_attributes['GRASS_BEND_DATA'].data[i].color=c
    obj['height_range_m']='0.48-0.70; varied lengths around 60% of a full block'
    obj['height_mean_m']=sum(heights)/len(heights)
    obj['deform_attribute']='GRASS_BEND_DATA: R=t^2, G=t, B=blade height/0.70m, A=1.'
    obj.data.update()
camera=bpy.data.objects['REVIEW_Camera_Hero']
camera.data.ortho_scale=2.55
camera.rotation_euler=(Vector((0,0,.82))-camera.location).to_track_quat('-Z','Y').to_euler()
detail=bpy.data.objects['REVIEW_Camera_Grass_Detail']
detail.data.ortho_scale=1.70
detail.rotation_euler=(Vector((0,0,1.33))-detail.location).to_track_quat('-Z','Y').to_euler()
back=bpy.data.objects['REVIEW_Camera_Block_Back']
back.data.ortho_scale=2.55
back.rotation_euler=(Vector((0,0,.82))-back.location).to_track_quat('-Z','Y').to_euler()
proxy=bpy.data.objects['DEMO_Player_Proxy']
for v in proxy.data.vertices:v.co.z*=.90/.54
notes=bpy.data.texts['REVIEW_NOTES'].as_string()
notes=notes.replace('B=blade height/0.38m','B=blade height/0.70m')
notes=notes.replace('49 leaves on a jittered 7x7 root grid, varied angles/heights, no thickness.','49 leaves on a jittered 7x7 root grid, varied angles/heights, no thickness.\nLeaf heights vary from about 0.48 to 0.70m, averaging near 0.60 of a full block.')
bpy.data.texts['REVIEW_NOTES'].clear();bpy.data.texts['REVIEW_NOTES'].write(notes)
(OUT/'REVIEW_NOTES.txt').write_text(notes,encoding='utf-8')
bpy.data.scenes['ENV_Player_Reaction_Demo'].frame_set(1)
if bpy.context.window:bpy.context.window.scene=main
main.frame_set(1);bpy.context.view_layer.update()
main.render.filepath=str(OUT/'preview_hero.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'grass_block_wind_v3.blend'))
bpy.ops.render.render(write_still=True)
print('HEIGHT_REVISED '+json.dumps({'minimum_m':min(heights),'maximum_m':max(heights),'mean_m':sum(heights)/len(heights)}))
