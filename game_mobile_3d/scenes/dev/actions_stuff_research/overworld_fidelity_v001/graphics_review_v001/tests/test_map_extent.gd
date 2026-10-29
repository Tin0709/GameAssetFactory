extends SceneTree
var errors:Array[String]=[]
func check(ok:bool,label:String)->void:
	if not ok:errors.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/MD2OverworldFidelityTest.tscn").instantiate();root.add_child(lab)
	check(lab.get_node("FlatGround").get_child(0).shape.size.x==100.,"Physical floor spans100m")
	check(lab.meadow.interaction.extent>=104.,"Grass interaction covers expanded field")
	check(lab.meadow.instance_count>15000,"Outer map contains real ground and vegetation")
	check(lab.get_node("FieldBoundary").get_child(0).position.x< -50.,"Boundary outside100m playable field")
	var found:=false
	for cell:Vector2i in lab.meadow._plant_cells:
		if cell.x>35:found=true;break
	check(found,"Vegetation exists beyond former map boundary")
	print("MAP_EXTENT_CHECKS ",JSON.stringify({"errors":errors,"field":lab.meadow.snapshot()}));lab.free();quit(0 if errors.is_empty()else 1)
