extends Node
## Samples nearby terrain to light only the portable character with native diffuse lighting.

const RECEIVER_LAYER := 1 << 19
const OFFSETS := [Vector3(1.1, 0., 1.45), Vector3(-1.1, 0., -1.45)]
const ATTENUATION := 1.2
const CLOSE_ATTENUATION := .85
const STEP_DROP := .43
const LUMA := Vector3(.2126, .7152, .0722)
const SURFACE_TINT := {
	"grass": Vector3(.97, 1.14, .84),
	"dirt": Vector3(1.20, 1.03, .84),
	"stone": Vector3(.93, 1.02, 1.10),
}

var supported := false
var _world: Node3D
var _world_environment: WorldEnvironment
var _receivers: Array[MeshInstance3D]
var _spots: Array[OmniLight3D]
var _targets: Array[Dictionary] = [{}, {}]
var _sample_next := true
var _power := 0.
var _last := Vector3.INF


static func available() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null


func setup(world: Node3D) -> void:
	_world = world
	_world_environment = world.get_node("WorldEnvironment")
	process_physics_priority = 12
	set_physics_process(false)
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		if (node.layers & RECEIVER_LAYER) != 0:
			return
	for row: Array in world.look.actor_materials:
		var mesh: MeshInstance3D = row[0]
		if mesh is MeshInstance3D and not _receivers.has(mesh):
			_receivers.append(mesh)
	if _receivers.is_empty():
		return
	for i in OFFSETS.size():
		var light := OmniLight3D.new()
		light.light_cull_mask = RECEIVER_LAYER
		light.light_specular = 0.
		light.omni_range = 4.2
		light.omni_attenuation = ATTENUATION
		light.light_energy = 0.
		light.hide()
		add_child(light)
		_spots.append(light)
	supported = true


func set_power(power: float) -> void:
	_power = clampf(power, 0., .85) if supported else 0.
	var receives := _power > 0.
	if receives == is_physics_processing():
		return
	_set_receiver_layers(receives)
	if not receives:
		for light in _spots:
			light.hide()
			light.light_energy = 0.
		_last = Vector3.INF
	set_physics_process(receives)


func _set_receiver_layers(enabled: bool) -> void:
	for mesh in _receivers:
		if is_instance_valid(mesh):
			mesh.set_layer_mask_value(20, enabled)


func _exit_tree() -> void:
	if supported and is_physics_processing():
		_set_receiver_layers(false)


func _sample_reflectors(sole: Vector3) -> void:
	var support: Dictionary = {}
	var checked_support := false
	for i in OFFSETS.size():
		var direction: Vector3 = OFFSETS[i]
		var ground: Dictionary = _world.terrain_contact_at(sole + direction, 2.55, .14)
		_targets[i] = ground
		if not ground.is_empty() and sole.y - ground.position.y <= STEP_DROP - .14:
			continue
		if not checked_support:
			support = _world.terrain_contact_at(sole, 2.55, .14)
			checked_support = true
		if support.is_empty() or (not ground.is_empty() and support.position.y - ground.position.y <= STEP_DROP):
			continue
		if ground.is_empty() and sole.y - support.position.y < .65:
			var chest := sole + Vector3.UP * .92
			var wall: Dictionary = _world.terrain_wall_contact_at(chest, direction)
			if not wall.is_empty():
				var reflected: Vector3 = wall.position + wall.normal * .19
				wall.position = reflected - Vector3.UP * .09
				# Limit the concentration of a broad wall reflection near the character.
				wall.gain = .56 * lerpf(.54, 1., smoothstep(.40, 1.15, chest.distance_to(reflected)))
				_targets[i] = wall
				continue
		var near: Dictionary = _world.terrain_contact_at(sole + direction * .34, 2.55, .14)
		if not near.is_empty() and (ground.is_empty() or near.position.y - ground.position.y > .16):
			near.attenuation = CLOSE_ATTENUATION
			_targets[i] = near


func _physics_process(delta: float) -> void:
	var sole: Vector3 = _world.player.global_position
	var reset := not _last.is_finite() or sole.distance_squared_to(_last) > 8.
	_last = sole
	if _sample_next or reset:
		_sample_reflectors(sole)
	_sample_next = not _sample_next
	var sky := _world_environment.environment.ambient_light_color.srgb_to_linear()
	var sky_tint := Vector3(sky.r, sky.g, sky.b)
	sky_tint /= maxf(.01, sky_tint.dot(LUMA))
	var blend := 1. - exp(-delta / .105)
	for i in _spots.size():
		var light := _spots[i]
		var target := _targets[i]
		var power := 0.
		if not _world.player.is_dead and not target.is_empty():
			var ground: Vector3 = target.position + Vector3.UP * .09
			var color: Vector3 = sky_tint.lerp(SURFACE_TINT.get(target.surface, Vector3.ONE), .62)
			color /= maxf(maxf(color.x, color.y), color.z)
			var rgb := Color(color.x, color.y, color.z).linear_to_srgb()
			power = _power * (1. - smoothstep(.55, 2.20, sole.y - ground.y)) * target.get("gain", 1.)
			var attenuation: float = target.get("attenuation", ATTENUATION)
			if not is_equal_approx(light.omni_attenuation, attenuation):
				light.omni_attenuation = attenuation if reset else lerpf(light.omni_attenuation, attenuation, blend)
			light.global_position = ground if reset else light.global_position.lerp(ground, blend)
			light.light_color = rgb if reset else light.light_color.lerp(rgb, blend)
		light.light_energy = power if reset else lerpf(light.light_energy, power, blend)
		if light.light_energy < .001:
			light.light_energy = 0.
		light.visible = light.light_energy > 0.
