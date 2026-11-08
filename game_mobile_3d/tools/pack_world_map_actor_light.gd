extends SceneTree
func _initialize():
 var a=OS.get_cmdline_user_args()
 if a.size()!=1:quit(2);return
 var meta=JSON.parse_string(FileAccess.get_file_as_string(a[0].path_join("metadata.json")))
 if not meta is Dictionary or meta.get("scope","")!="Original GAF actor incident field; not MD2 radiance":quit(2);return
 var r=Resource.new()
 for k in meta:r.set_meta(k,meta[k])
 for k in ["sky","sun"]:
  var v=FileAccess.get_file_as_bytes(a[0].path_join(k+".bin")).to_float32_array()
  if v.size()!=int(meta.probe_count)*18:quit(2);return
  r.set_meta(k,v)
 r.set_meta("valid",FileAccess.get_file_as_bytes(a[0].path_join("valid.bin")))
 var folder="res://assets/graphics/world_map_actor_light_v001"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 quit(ResourceSaver.save(r,folder.path_join("field.res"),ResourceSaver.FLAG_COMPRESS))
