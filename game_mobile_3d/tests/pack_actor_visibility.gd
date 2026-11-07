extends SceneTree
# Companion authoring step. Outputs only new original visibility resources.
func _initialize()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:push_error("Supply the baker scratch folder after --");quit(2);return
    var folder:String=args[0]
    var description:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("header.json")))
    var profile_script:Script=load("res://scripts/world_map_sky_probe.gd")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/graphics/world_map_actor_sky_v001"))
    var variants:Array[String]=["tree_oak_a","tree_oak_b"]
    for i in 2:
        var raw:PackedFloat32Array=FileAccess.get_file_as_bytes(folder.path_join(variants[i]+".bin")).to_float32_array()
        if raw.size()!=93750:push_error("Unexpected original visibility grid size");quit(2);return
        var profile:Resource=profile_script.new()
        profile.set_meta("source_generator_sha256",description.source_sha256)
        profile.set_meta("original_gaf_asset",variants[i])
        profile.set_meta("visibility_rays",192)
        profile.coefficients.resize(28125)
        for probe in 9375:
            var offset:=probe*10
            profile.coefficients[probe*3]=Vector4(raw[offset],raw[offset+1],raw[offset+2],raw[offset+3])
            profile.coefficients[probe*3+1]=Vector4(raw[offset+4],raw[offset+5],raw[offset+6],raw[offset+7])
            profile.coefficients[probe*3+2]=Vector4(raw[offset+8],raw[offset+9],0,0)
        var destination:String="res://assets/graphics/world_map_actor_sky_v001/oak_sky_%s.res"%["a" if i==0 else "b"]
        if ResourceSaver.save(profile,destination,ResourceSaver.FLAG_COMPRESS)!=OK:quit(2);return
    print("Original GAF visibility resources packed;192rays,9375probes per original crown; source ",description.source_sha256)
    quit()
