extends SceneTree
## Pack only the original GAF authoring result, never a proprietary reference dump.
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var folder:=args[0];var meta:Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("metadata.json")))
	if not meta is Dictionary or meta.get("scope","")!="Original GAF static diffuse transport; not native Lumen":quit(2);return
	var resource:=Resource.new()
	for key in meta:resource.set_meta(key,meta[key])
	for key in ["sky","sun"]:
		var data:=FileAccess.get_file_as_bytes(folder.path_join(key+".bin")).to_float32_array()
		if data.size()!=int(meta.count)*3:quit(2);return
		resource.set_meta(key,data)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/graphics/world_map_terrain_transport_v001"))
	quit(ResourceSaver.save(resource,"res://assets/graphics/world_map_terrain_transport_v001/transport.res",ResourceSaver.FLAG_COMPRESS))
