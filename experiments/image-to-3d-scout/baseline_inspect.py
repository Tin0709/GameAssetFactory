import bpy
from collections import Counter
for s in bpy.data.scenes:
 if s.name.startswith('Scout'):
  print('SCOUT_SCENE', s.name,Counter(o.type for o in s.objects), [c.name for c in s.collection.children],[(m.name,m.frame) for m in s.timeline_markers])
