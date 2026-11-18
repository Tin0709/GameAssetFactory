extends SceneTree

const PATH := "res://scripts/world_map_far_terrain_shadow.gd"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)

func write(path: String,value: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(value)

func write_manifest(directory: String,value: Dictionary) -> void:
	write(directory.path_join("depth_manifest.json"),JSON.stringify(value))

func make_manifest(layout_hash: String) -> Dictionary:
	var key := {"minute":1000,"file":"case_1000.r16z","raw_sha256":"a".repeat(64),"packed_bytes":32,
		"axis_x":[1.,0.,0.,0.],"axis_y":[0.,1.,0.,0.],"axis_z":[0.,0.,1.,0.],
		"light":[0.,0.,1.],"span":1.,"depth_range":1.}
	var next := key.duplicate(true)
	next.minute=1003
	next.file="case_1003.r16z"
	var zone := {"id":"test","anchor":[0.,0.,0.],"radius_m":8.,"groups":["FixtureTerrain"],"keys":[key,next]}
	return {"format":1,"resolution":384,"first_minute":1000,"last_minute":1003,
		"layout_sha256":layout_hash,"zones":[zone]}

func run() -> void:
	check(ResourceLoader.exists(PATH),"Far terrain shadow module is available in project")
	if not failures.is_empty():
		finish()
		return
	var source: Script=load(PATH)
	check(source!=null and source.can_instantiate(),"The shared module can be instantiated")
	if not failures.is_empty():
		finish()
		return
	var renderer: Node=source.new()
	check(renderer.has_method("configure"),"The caller supplies the scene inputs and manifest")
	check(renderer.has_method("update_shadow"),"The caller supplies the current light/gameplay context")
	check(not renderer.configure(null,null,[],"",""),"Missing setup data leaves the controller inert")
	check(renderer.snapshot().zone=="" and renderer.snapshot().resident==0,"Rejected setup leaves empty shadow state")
	check(not renderer.register_globals(),"Headless mode does not register runtime shader state")
	renderer.free()

	var fixture:=Node3D.new()
	root.add_child(fixture)
	var light:=DirectionalLight3D.new()
	var view:=Camera3D.new()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=BoxMesh.new()
	mesh.name="FixtureTerrain"
	var caste:=MeshInstance3D.new()
	caste.mesh=mesh.mesh
	for node in [light,view,mesh,caste]:
		fixture.add_child(node)
	var chunks := [{"visual":mesh,"caster":caste}]
	var directory:=ProjectSettings.globalize_path("user://test_far_shadow_manifest")
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	var layout:=directory.path_join("test.layout")
	write(layout,"Original GameAssetFactory test fixture")
	var manifest:=make_manifest(FileAccess.get_sha256(layout))
	var changes: Array[Dictionary] = []
	for field in ["layout_sha256","format","resolution"]:
		var bad:=manifest.duplicate(true)
		bad[field]="mismatch"
		changes.append(bad)
	for field in ["id","groups","anchor","radius_m"]:
		var bad:=manifest.duplicate(true)
		bad.zones[0][field]=null
		changes.append(bad)
	var duplicates:=manifest.duplicate(true)
	duplicates.zones.append(duplicates.zones[0].duplicate(true))
	changes.append(duplicates)
	var backwards:=manifest.duplicate(true)
	backwards.zones[0].keys.reverse()
	changes.append(backwards)
	var key_cases := {"minute":"late","file":"../escape.r16z","raw_sha256":"12",
		"packed_bytes":1073741824,"axis_x":[0.],"axis_y":[0.,0.,"z",0.],
		"axis_z":[0.,0.,0.,0.],"light":[0.,0.,0.],"span":0.,"depth_range":-1.}
	for field: String in key_cases:
		var bad:=manifest.duplicate(true)
		bad.zones[0].keys[0][field]=key_cases[field]
		changes.append(bad)
	var before := light.shadow_caster_mask
	for bad: Dictionary in changes:
		write_manifest(directory,bad)
		var sample: Node=source.new()
		check(not sample.configure(light,view,chunks,directory,layout),"Reject malformed manifest %d" % checks)
		check(sample.snapshot().resident==0 and light.shadow_caster_mask==before and mesh.layers==1 and caste.layers==1,
			"Malformed manifest leaves existing shadow state untouched")
		sample.free()
	write_manifest(directory,manifest)
	var valid: Node=source.new()
	check(valid.configure(light,view,chunks,directory,layout),"Well-formed manifest accepts original geometry")
	check(not valid.configure(light,view,chunks,directory,layout),"Mounted cache remains owned by the same controller")
	check(valid.snapshot().zone=="" and valid.snapshot().resident==0,"Configuration avoids texture allocation")
	valid.free()
	fixture.free()
	finish()

func finish() -> void:
	print("FAR_PROJECT_CONTRACT ",checks," checks, failures=",failures)
	quit(0 if failures.is_empty() else 1)

