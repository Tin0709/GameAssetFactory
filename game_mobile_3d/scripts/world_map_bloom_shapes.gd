extends RefCounted
## Private numeric kernel data; implementation and viewport transfer are original.
const FILE="godot_lab/world_map_unified_showcase_v001/multiscale_bloom_v001/shape_transfer_v001/profile.private.json"
const SHA="b2b4473038260b52ed1775873c8ac2a7dda49e0d5eaad23f71bebed0dff2e365"
var levels:Array=[]
func _init()->void:
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema")!="private-forest-bloom-shape/1":return
 var rows=data.get("levels_fine_to_coarse")
 if not rows is Array or rows.size()!=6:return
 for row in rows:
  if not row is Dictionary:return
  for axis in ["h","v"]:
   var taps=row.get(axis)
   if not taps is Array or taps.is_empty()or taps.size()>32:return
   for tap in taps:
    if not tap is Array or tap.size()!=3:return
    for n in tap:
     if not(n is float or n is int)or not is_finite(n):return
    if absf(tap[0])>4. or absf(tap[1])>4. or tap[2]<0. or tap[2]>2.:return
 levels=rows
func available()->bool:return levels.size()==6
