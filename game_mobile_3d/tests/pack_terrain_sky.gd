extends SceneTree
# Packs only the original GAF visibility bake; never imports game references.
func _initialize()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:push_error("Supply completed original terrain-sky bake directory");quit(2);return
    var folder:String=args[0]
    var info:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("metadata.private.json")))
    var values:PackedFloat32Array=FileAccess.get_file_as_bytes(folder.path_join("visibility.private.bin")).to_float32_array()
    if info.get("source_runtime_sha256","")!=FileAccess.get_sha256("res://assets/maps/world_map/runtime.json") or values.size()!=int(info.full_vertices):
        push_error("Visibility source map/size mismatch");quit(2);return
    var count:=0
    for row:Dictionary in info.rows:
        if int(row.start)!=count:push_error("Noncontiguous source rows");quit(2);return
        count+=int(row.count)
    for value:float in values:
        if not is_finite(value) or value<0. or value>1.:push_error("Invalid visibility");quit(2);return
    if count!=values.size():push_error("Incomplete visibility rows");quit(2);return
    var cache:=Resource.new()
    cache.set_meta("rows",info.rows);cache.set_meta("values",values)
    cache.set_meta("source_runtime_sha256",info.source_runtime_sha256)
    cache.set_meta("ambient_srgb",Color(info.ambient_srgb[0],info.ambient_srgb[1],info.ambient_srgb[2]))
    cache.set_meta("rays",info.rays);cache.set_meta("model_version",1)
    cache.set_meta("ownership","Original GAF upper-sky luma visibility; no MD2 data")
    var path:="res://assets/graphics/world_map_terrain_sky_v001/visibility.res"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    var error:=ResourceSaver.save(cache,path,ResourceSaver.FLAG_COMPRESS)
    print("TERRAIN_SKY_PACK vertices=",values.size()," bytes=",values.size()*4," error=",error);quit(0 if error==OK else 1)
