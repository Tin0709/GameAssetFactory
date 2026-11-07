extends SceneTree
# Packs only original GAF unit-sun ground radiance produced by the native baker.
func _initialize()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:push_error("Supply original bake output directory after --");quit(2);return
    var folder:String=args[0]
    var info:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("metadata.private.json")))
    var size:=Vector2i(info.size[0],info.size[1]);var bytes:=FileAccess.get_file_as_bytes(folder.path_join("radiance_rgba32.private.bin"))
    if bytes.size()!=size.x*size.y*16:push_error("Unexpected radiance payload");quit(2);return
    var image:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBAF,bytes);image.convert(Image.FORMAT_RGBAH)
    var texture:=ImageTexture.create_from_image(image)
    texture.set_meta("origin",Vector2(info.origin[0],info.origin[1]))
    texture.set_meta("extent",Vector2(info.extent[0],info.extent[1]))
    texture.set_meta("sun_direction",Vector3(info.sun_direction[0],info.sun_direction[1],info.sun_direction[2]))
    texture.set_meta("source_map_sha256",info.source_sha256)
    texture.set_meta("source_runtime_sha256",info.get("source_runtime_sha256",FileAccess.get_sha256("res://assets/maps/world_map/runtime.json")))
    texture.set_meta("ownership","Original GAF normalized Lambert ground radiance; no MD2 data")
    texture.set_meta("model_version",1)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/graphics/world_map_ground_bounce_v001"))
    var error:=ResourceSaver.save(texture,"res://assets/graphics/world_map_ground_bounce_v001/normalized_ground.res",ResourceSaver.FLAG_COMPRESS)
    print("ORIGINAL_GROUND_PACK size=",size," payload_bytes=",size.x*size.y*8," error=",error);quit(0 if error==OK else 1)
