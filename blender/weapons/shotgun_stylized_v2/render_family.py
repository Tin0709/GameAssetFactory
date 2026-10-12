"""Presentation only: true common-scale family and transparent asset thumbnail."""
import bpy,sys
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;SHOW=HERE.parent/'showcase'
sys.path.insert(0,str(SHOW));import gaf_weapon_library as lib
lib.register();bpy.ops.wm.open_mainfile(filepath=str(SHOW/'Weapon_Showcase.blend'));s=bpy.context.scene
s.render.threads_mode='FIXED';s.render.threads=8;s.cycles.samples=32;out=HERE/'review'
s.gaf_weapon_index=next(i for i,e in enumerate(lib.entries(s)) if e['id']=='shotgun_stylized_v2');s.gaf_fit_mode='STANDALONE';lib.activate(s)
lib.view(s,'THREE_QUARTER');s.render.film_transparent=True;s.render.filepath=str(out/'shotgun_v2_isometric_transparent.png');bpy.ops.render.render(write_still=True)
obs=[]
for id,z in [('rifle_stylized_v2',.45),('shotgun_stylized_v2',.05),('pistol_stylized_v2',-.30)]:
 e=next(e for e in lib.entries(s) if e['id']==id);c=bpy.data.collections[e['collection']];c.hide_render=c.hide_viewport=False
 lib.root_of(e).matrix_world=Matrix.Translation(Vector((0,0,z)));obs+=list(c.objects)
bpy.context.view_layer.update();center,dims=lib.bounds(obs);cam=s.camera;cam.location=center+Vector((3,-.2,.4)).normalized()*3
cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();inv=cam.rotation_euler.to_matrix().transposed()
ps=[inv@(o.matrix_world@Vector(c)-center) for o in obs if o.type=='MESH' for c in o.bound_box]
low=[min(p[i] for p in ps) for i in range(2)];high=[max(p[i] for p in ps) for i in range(2)]
cam.location+=cam.rotation_euler.to_matrix()@Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,0))
cam.data.ortho_scale=max(high[0]-low[0],(high[1]-low[1])*s.render.resolution_x/s.render.resolution_y)*1.18
s.render.film_transparent=False;s.render.filepath=str(out/'weapon_family_common_scale.png');bpy.ops.render.render(write_still=True)
print('FAMILY_RENDERED: rifle / shotgun / pistol; all source scale 1; presentation translations only; no blend save')
