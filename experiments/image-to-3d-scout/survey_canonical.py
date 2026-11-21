import bpy, json
from collections import Counter
s=bpy.data.scenes['Scout - Canonical Silhouette']
for c in s.collection.children['Scout Canon | Character'].children:
 print('GROUP',c.name)
 for o in c.objects:
  if o.type=='MESH':
   print('PART',o.name[13:],len(o.data.vertices), [m.name[13:] for m in o.data.materials],len(o.data.uv_layers))
for s in [bpy.data.scenes.get('Scout - Rogue Archer'),bpy.data.scenes.get('Scout - Reference Character')]:
 print('OLD',s.name,s.camera.name,s.frame_current)
 print('IMAGES',[(i.name, list(i.size),bool(i.packed_file)) for i in bpy.data.images if 'Rogue' in i.name or 'Scout' in i.name])
