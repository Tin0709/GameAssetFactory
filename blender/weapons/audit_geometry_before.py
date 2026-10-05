import bpy,bmesh,json
from pathlib import Path
base=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
files={'Pistol':'pistol/blocky_pistol_v1.blend','M4A1':'m4a1_blocky/m4a1_blocky_v2.blend','Shotgun':'shotgun/blocky_shotgun_v1.blend'}
r={}
for key,f in files.items():
 bpy.ops.wm.open_mainfile(filepath=str(base/f));bpy.context.view_layer.update();items=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(o.data);remain=set(bm.verts);islands=[]
  while remain:
   stack=[remain.pop()];vs=[]
   while stack:
    v=stack.pop();vs.append(v)
    for e in v.link_edges:
     n=e.other_vert(v)
     if n in remain:remain.remove(n);stack.append(n)
   islands.append(len(vs))
  for g in o.vertex_groups:
   vs=[v.co for v in o.data.vertices if any(i.group==g.index for i in v.groups)]
   if vs:items.append({'part':g.name,'bounds':[[min(v[i] for v in vs),max(v[i] for v in vs)] for i in range(3)]})
  items.append({'mesh':o.name,'islands':len(islands),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'loose_vertices':sum(not v.link_faces for v in bm.verts)})
  bm.free()
 r[key]=items
(base/'geometry_cleanup_before.json').write_text(json.dumps(r,indent=2))
result=r
