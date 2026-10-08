extends "res://scripts/grassland.gd"
## Review-only presentation. Original resources/state are captured before any styling.
const LOOK_GRASS = preload("res://materials/lookdev_grass.gdshader")
const LOOK_TERRAIN = preload("res://materials/lookdev_terrain.gdshader")
const SUN_PROPERTIES := ["rotation", "light_color", "light_energy", "light_angular_distance", "shadow_enabled", "shadow_bias", "shadow_normal_bias", "shadow_opacity", "directional_shadow_mode", "directional_shadow_max_distance", "directional_shadow_blend_splits"]
var new_look := true
var high_quality := false
var original_environment: Environment
var styled_environment: Environment
var original_grass: ShaderMaterial
var styled_grass: ShaderMaterial
var styled_terrain: ShaderMaterial
var original_sun := {}
var terrain_states: Array[Dictionary] = []
var grass_states: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	original_environment = $WorldEnvironment.environment
	original_grass = grass_material
	for property in SUN_PROPERTIES: original_sun[property] = $Sun.get(property)
	for chunk in $Terrain.get_children():
		terrain_states.append({"node": chunk, "material": chunk.material_override, "shadow": chunk.cast_shadow})
	for chunk in $Grass.get_children():
		grass_states.append({"node": chunk, "material": chunk.material_override, "shadow": chunk.cast_shadow})
	styled_environment = original_environment.duplicate()
	styled_environment.background_color = Color(0.52, 0.61, 0.64)
	styled_environment.ambient_light_color = Color(0.66, 0.77, 0.91)
	styled_environment.ambient_light_energy = 0.60
	styled_environment.fog_light_color = Color(0.58, 0.67, 0.69)
	styled_environment.fog_light_energy = 0.7
	styled_environment.fog_density = 0.0035
	styled_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	styled_grass = ShaderMaterial.new()
	styled_grass.shader = LOOK_GRASS
	styled_grass.set_shader_parameter("atlas", ATLAS)
	styled_grass.set_shader_parameter("wind_direction", wind_direction)
	styled_grass.set_shader_parameter("wind_strength", wind_strength)
	styled_terrain = ShaderMaterial.new()
	styled_terrain.shader = LOOK_TERRAIN
	styled_terrain.set_shader_parameter("atlas", ATLAS)
	styled_terrain.set_shader_parameter("root_shade", build_root_shade())
	set_look(true)

func build_root_shade() -> ImageTexture:
	# Baked once from the actual seeded patch positions; one small texture sample per ground pixel.
	# Soft overlapping roots, no transparent quads, lights or per-patch physics.
	var image := Image.create(512, 512, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for transform in grass_transforms:
		var center := Vector2(transform.origin.x + 20.0, transform.origin.z + 20.0) * 12.8
		for y in range(maxi(0, int(center.y) - 11), mini(512, int(center.y) + 12)):
			for x in range(maxi(0, int(center.x) - 11), mini(512, int(center.x) + 12)):
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) / 12.8
				var shade := (1.0 - smoothstep(0.14, 0.82, distance)) * 0.86
				image.set_pixel(x, y, Color(maxf(image.get_pixel(x, y).r, shade), 0, 0))
	return ImageTexture.create_from_image(image)

func set_look(enabled: bool) -> void:
	new_look = enabled
	$WorldEnvironment.environment = styled_environment if enabled else original_environment
	grass_material = styled_grass if enabled else original_grass
	motion.publish(grass_material)
	for state in terrain_states:
		state.node.material_override = styled_terrain if enabled else state.material
		state.node.cast_shadow = state.shadow
	for state in grass_states:
		state.node.material_override = styled_grass if enabled else state.material
		state.node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if high_quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF) if enabled else state.shadow
	if enabled:
		$Sun.rotation_degrees = Vector3(-48, -42, 0)
		$Sun.light_color = Color(1.0, 0.88, 0.69)
		$Sun.light_energy = 1.25
		$Sun.light_angular_distance = 0.35
		$Sun.shadow_bias = 0.025
		$Sun.shadow_normal_bias = 0.65
		$Sun.shadow_opacity = 0.84
		$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		$Sun.directional_shadow_max_distance = 29.0
		$Sun.directional_shadow_blend_splits = false
	else:
		for property in original_sun: $Sun.set(property, original_sun[property])
	update_help()

func set_quality(high: bool) -> void:
	high_quality = high
	set_look(new_look)

func update_help() -> void:
	$HUD/Help.text = "GRASSLAND LOOK-DEV  ·  %s\nF1 Current  ·  F2 New  ·  Tab A/B  ·  F3 Mobile / High\nWASD move  ·  Shift sprint  ·  R center\nARTISTIC STATUS: AWAITING HUMAN REVIEW" % ("NEW / HIGH REVIEW" if new_look and high_quality else ("NEW / MOBILE" if new_look else "CURRENT / ORIGINAL"))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	styled_terrain.set_shader_parameter("player_position", player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1: set_look(false)
			KEY_F2: set_look(true)
			KEY_TAB: set_look(not new_look)
			KEY_F3: set_quality(not high_quality)
