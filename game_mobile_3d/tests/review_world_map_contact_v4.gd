extends SceneTree
## Real GPU shading probes plus reproducible F5-scene pixels. Dummy audio at launch.
const OUT := "res://.validation/world_map/contact_v4/"
var view: SubViewport
var failures: Array[String]=[]
var prefix := "after"

func _initialize() -> void:
	root.visible=false
	create_timer(100).timeout.connect(func():quit(2))
	call_deferred("run")

func capture(label: String) -> Image:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image()
	assert(image.save_png(OUT+prefix+"_"+label+".png")==OK)
	return image

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)

func probe() -> void:
	var fixture:=Node3D.new();view.add_child(fixture)
	var camera:=Camera3D.new();fixture.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9.0
	camera.position=Vector3(0,0,10);camera.current=true
	var heights:=Image.create(8,8,false,Image.FORMAT_RGBAF)
	heights.fill(Color(0,0,0,1))
	heights.set_pixel(1,2,Color(0,2,0,1))
	heights.set_pixel(2,1,Color(0,2,0,1))
	heights.set_pixel(5,5,Color(0,2,0,1))
	var texture:=ImageTexture.create_from_image(heights)
	var source: String=load("res://scripts/world_map_look.gd").PRESET.ground_shader.code
	var pattern:=RegEx.new();pattern.compile('res://materials/world_map_surface[^" ]*')
	var include: String=pattern.search(source).get_string()
	if prefix=="before":include="res://materials/world_map_surface.gdshaderinc"
	var shader:=Shader.new()
	shader.code='shader_type spatial; render_mode unshaded;\n#include "'+include+'"\nuniform vec3 sample_point; uniform vec3 sample_normal; void fragment(){ALBEDO=vec3(terrain_contact_shade(sample_point,sample_normal));}'
	var specs: Array=[
		["flat_left",Vector3(3.9999,0,4.5),Vector3.UP],
		["flat_right",Vector3(4.0001,0,4.5),Vector3.UP],
		["ground_foot",Vector3(2.02,0,2.5),Vector3.UP],
		["ground_clear",Vector3(2.8,0,2.5),Vector3.UP],
		["wall_foot",Vector3(2,.02,2.5),Vector3.RIGHT],
		["wall_clear",Vector3(2,1.4,2.5),Vector3.RIGHT],
		["concave",Vector3(2,1.4,2.03),Vector3.RIGHT],
		["convex",Vector3(1,1.4,2.5),Vector3.LEFT],
		["above_neighbour",Vector3(2,2.2,2.03),Vector3.RIGHT],
		["vertical_below",Vector3(2,.9999,2.03),Vector3.RIGHT],
		["vertical_above",Vector3(2,1.0001,2.03),Vector3.RIGHT],
		["ground_corner",Vector3(2.02,0,2.02),Vector3.UP],
		["diagonal_tip",Vector3(6.02,0,6.02),Vector3.UP],
		["tip_cardinal",Vector3(6.02,0,5.98),Vector3.UP],
		["diagonal_far",Vector3(6.7,0,6.7),Vector3.UP]]
	var pixels: Dictionary={}
	for i in specs.size():
		var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(1.5,1.3)
		fixture.add_child(mesh);mesh.position=Vector3((i%3-1)*2.3,(1.5-floori(i/3.0))*1.7,0)
		var mat:=ShaderMaterial.new();mat.shader=shader
		mat.set_shader_parameter("sample_point",specs[i][1]);mat.set_shader_parameter("sample_normal",specs[i][2])
		mat.set_shader_parameter("ground_grade",2);mat.set_shader_parameter("path_blending",true)
		mat.set_shader_parameter("path_surface_map",texture);mat.set_shader_parameter("path_map_size",Vector2(8,8))
		mesh.material_override=mat;pixels[specs[i][0]]=Vector2i(camera.unproject_position(mesh.position))
	var image:=await capture("probe")
	var values: Dictionary={}
	for label: String in pixels:
		var c:=image.get_pixelv(pixels[label]).srgb_to_linear()
		values[label]=(c.r+c.g+c.b)/3.0
	var white: float=values.flat_left
	check(absf(values.flat_left-values.flat_right)<.005,"Flat adjacent blocks must have no seam")
	check(absf(values.ground_clear-white)<.005,"Contact must fade out away from wall")
	check(values.ground_foot<white*.80,"Ground contact should be clearly readable")
	check(values.wall_foot<white*.82,"Wall foot should shade upward from contact")
	check(values.concave<white*.84,"Concave wall corner should have local depth")
	check(absf(values.convex-white)<.005,"Convex wall edge must not get a dark outline")
	check(absf(values.above_neighbour-white)<.005,"Corner shade must end above occluding neighbour")
	check(absf(values.wall_clear-white)<.005,"Wall outside contact bands keeps original albedo")
	check(absf(values.vertical_below-values.vertical_above)<.005,"Wall shading must not reset at stacked block seam")
	check(values.ground_corner<=values.ground_foot+.005,"Ground concavity should support two contacting walls")
	check(values.diagonal_tip<white*.80,"Ground shadow must wrap around an isolated block's sharp corner")
	check(absf(values.diagonal_tip-values.tip_cardinal)<.015,"Ground contact must stay continuous across the corner cell boundary")
	check(absf(values.diagonal_far-white)<.005,"Diagonal corner shade must fade away without a square patch")
	var fade_source: String=load("res://scripts/world_map_geometry.gd").LOOK_PRESET.cutaway_shader.code
	var fade_include: String=pattern.search(fade_source).get_string()
	if prefix=="before":fade_include="res://materials/world_map_surface.gdshaderinc"
	shader.code=shader.code.replace(include,fade_include)
	var fade_image:=await capture("cutaway_probe")
	var maximum_fade_delta:=0.0
	for label: String in pixels:
		var c:=fade_image.get_pixelv(pixels[label]).srgb_to_linear()
		maximum_fade_delta=maxf(maximum_fade_delta,absf((c.r+c.g+c.b)/3.0-values[label]))
	check(maximum_fade_delta<.005,"Opaque and cutaway contact shading must match")
	FileAccess.open(OUT+prefix+"_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"shader_include":include,"cutaway_include":fade_include,"maximum_cutaway_delta":maximum_fade_delta,"linear_pixel_values":values,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()},"\t"))
	print("CONTACT_PROBE ",prefix," ",values," failures=",failures)
	fixture.queue_free();await process_frame

func run() -> void:
	prefix="before" if "--before" in OS.get_cmdline_user_args() else "after"
	DirAccess.make_dir_recursive_absolute(OUT)
	view=SubViewport.new();view.size=Vector2i(1280,720);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	await probe()
	var level: Node3D=load("res://scenes/WorldMap.tscn").instantiate();view.add_child(level)
	for i in 30:await physics_frame
	level.set_process(false);level.player.set_physics_process(false);level.player.visual.set_process(false)
	level.look.freeze_motion(0.0);level.look.publish_clouds(0.0);level.get_node("HUD").hide()
	if prefix=="before":
		for item: Array in level.look.terrain_materials:item[3].shader=load("res://materials/world_map_ground.gdshader")
		for material: ShaderMaterial in level.look.wind_materials:
			if material.shader==level.look.PRESET.plants_shader:material.shader=load("res://materials/world_map_plants_v3.gdshader")
		for item: Dictionary in level.geometry._cutaway_chunks:
			for material: ShaderMaterial in item.materials:material.shader=load("res://materials/world_map_cutaway.gdshader")
	await capture("gameplay")
	for spec: Array in [["cliffs",Vector2(40,-31)],["terraces",Vector2(31,-22)],["grove",Vector2(-26,6)],["stairs",Vector2(-43,-40)],["stone",Vector2(-40,-44)],["south",Vector2(43,43)]]:
		var p: Vector2=spec[1];var h: float=level.surface_height(p.x,p.y)
		if not is_finite(h):continue
		level.player.position=Vector3(p.x,h+.02,p.y);level.set_review_view("gameplay")
		level.geometry.update_cutaway(level.player.position,level.get_node("Camera3D").position)
		if prefix=="before":
			for item: Dictionary in level.geometry._cutaway_chunks:
				for material: ShaderMaterial in item.materials:material.shader=load("res://materials/world_map_cutaway.gdshader")
		await capture(spec[0])
	level.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
