extends SceneTree
func _initialize():call_deferred("run")
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 for i in 32:await process_frame
 var ok=w.showcase.has_method("set_source_point_cutoff")
 print("POINT_CUTOFF_API ",ok);w.free();await process_frame;quit(0 if ok else 1)
