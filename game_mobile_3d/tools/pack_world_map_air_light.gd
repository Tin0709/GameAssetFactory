extends SceneTree
func _initialize():
 var a=OS.get_cmdline_user_args()
 if a.size()!=1:quit(2);return
 var m=JSON.parse_string(FileAccess.get_file_as_string(a[0].path_join("metadata.json")))
 if not m is Dictionary or m.get("scope","")!="Original GAF static sun visibility, not native light shafts":quit(2);return
 var r=Resource.new()
 for k in m:r.set_meta(k,m[k])
 var bytes=FileAccess.get_file_as_bytes(a[0].path_join("visibility.bin"))
 if bytes.size()!=int(m.probe_count):quit(2);return
 r.set_meta("visibility",bytes)
 var folder="res://assets/graphics/world_map_air_light_v001";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var e=ResourceSaver.save(r,folder.path_join("visibility.res"),ResourceSaver.FLAG_COMPRESS)
 var image=Image.create_from_data(64,64,false,Image.FORMAT_RGH,FileAccess.get_file_as_bytes(a[0].path_join("brdf.bin")))
 var tex=ImageTexture.create_from_image(image)
 e=e|ResourceSaver.save(tex,folder.path_join("brdf.res"),ResourceSaver.FLAG_COMPRESS);quit(e)
