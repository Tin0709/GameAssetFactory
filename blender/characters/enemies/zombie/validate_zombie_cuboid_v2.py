import bpy,json,hashlib
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/enemies/zombie')
PLAYER=OUT.parents[1]/'player/cuboid/player_cuboid_v6.blend'
bpy.ops.wm.open_mainfile(filepath=str(PLAYER))
p=bpy.data.objects['Player_Cuboid_Base'];pr=bpy.data.objects['Player_Cuboid_Rig']
reference={'vertices':[list(v.co) for v in p.data.vertices],'faces':[list(f.vertices) for f in p.data.polygons],'uv':[list(x.uv) for x in p.data.uv_layers.active.data],'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in pr.data.bones]}
bpy.ops.wm.open_mainfile(filepath=str(OUT/'zombie_cuboid_v1.blend'))
original=list(bpy.data.images['Zombie_Original_Atlas_64'].pixels)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'zombie_cuboid_v2.blend'))
s=bpy.context.scene;m=bpy.data.objects['Zombie_Cuboid_Base'];r=bpy.data.objects['Zombie_Cuboid_Rig'];parts=json.loads(m['rigid_parts'])
assert reference['vertices']==[list(v.co) for v in m.data.vertices]
assert reference['faces']==[list(f.vertices) for f in m.data.polygons]
assert reference['uv']==[list(x.uv) for x in m.data.uv_layers.active.data]
assert reference['bones']==[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in r.data.bones]
assert original==list(bpy.data.images['Zombie_Original_Atlas_64'].pixels)
assert len(parts)==6 and len(r.data.bones)==10
assert all(len(v.groups)==1 and v.groups[0].weight==1 for v in m.data.vertices)
assert all(not p.constraints for p in r.pose.bones)
assert all(p['vertex_count']==8 for p in parts)
# Each part has eight extreme corner vertices and six quads: no intermediate rings.
for p in parts:
 indices=set(range(p['first_vertex'],p['first_vertex']+8))
 assert len([f for f in m.data.polygons if set(f.vertices)<=indices])==6
 for axis in range(3):assert len({round(m.data.vertices[i].co[axis],6) for i in indices})==2

def reset():
 for p in r.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
def pos(f):
 s.frame_set(int(f),subframe=f-int(f));o=m.evaluated_get(bpy.context.evaluated_depsgraph_get());dm=o.to_mesh();vs=[v.co.copy() for v in dm.vertices];o.to_mesh_clear();return vs
baseline=[(m.data.vertices[e.vertices[0]].co-m.data.vertices[e.vertices[1]].co).length for e in m.data.edges]
report={}
for name,N in [('Zombie_Idle',48),('Zombie_Walk',32)]:
 reset();r.animation_data.action=bpy.data.actions[name];first=pos(1);last=pos(N+1);closure=max((a-b).length for a,b in zip(first,last));error=0;floor=1e9
 for i in range(N*4+1):
  vs=pos(1+i/4)
  error=max(error,max(abs((vs[e.vertices[0]]-vs[e.vertices[1]]).length-b) for e,b in zip(m.data.edges,baseline)))
  floor=min(floor,min(v.z for v in vs))
  assert max(abs(r.pose.bones['Root'].matrix[a][b]-r.data.bones['Root'].matrix_local[a][b]) for a in range(4) for b in range(4))<1e-7
  assert all(all(abs(x-1)<1e-7 for x in p.scale) for p in r.pose.bones)
 assert error<1e-6 and closure<1e-6
 report[name]={'rigid_edge_error_m':error,'loop_vertex_error_m':closure,'minimum_floor_z_m':floor,'root_stationary':True,'unit_scales':True}
report.update({'matches_player_v6_mesh_uv_and_rig_exactly':True,'texture_matches_zombie_v1_exactly':True,'no_intermediate_limb_vertices':True,'height_m':1.8,'triangles':72,'bones':10})
(OUT/'zombie_v2_validation.json').write_text(json.dumps(report,indent=2))
reset();r.animation_data.action=bpy.data.actions['Zombie_Idle'];s.frame_set(1)
s.render.resolution_x=768;s.render.resolution_y=768;s.render.resolution_percentage=100;s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.color_mode='RGBA'
for angle in ['Front','Isometric','Side']:
 s.camera=bpy.data.objects['Zombie '+angle+' Camera'];s.camera.data.ortho_scale=2.5;s.render.filepath=str(OUT/('zombie_cuboid_v2_'+angle.lower()+'.png'));bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['Zombie Isometric Camera'];s.render.filepath=str(OUT/'zombie_cuboid_v2_isometric.png')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'zombie_cuboid_v2.blend'))
# Unsaved render settings for animation pose review, separate from V1 previews.
s.render.resolution_x=384;s.render.resolution_y=384;s.cycles.samples=16
folder=OUT/'v2_walk_pose_review';folder.mkdir(exist_ok=True)
reset();r.animation_data.action=bpy.data.actions['Zombie_Walk']
for f in [1,5,9,13,17,21,25,29]:
 s.frame_set(f);s.render.filepath=str(folder/f'{f:02d}.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'zombie_cuboid_v2.blend'))
result=report
