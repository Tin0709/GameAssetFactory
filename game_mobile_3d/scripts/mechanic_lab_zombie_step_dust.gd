extends MultiMeshInstance3D

const MovementDust := preload("res://scripts/mechanic_lab_movement_dust.gd")
const SHADER := preload("res://materials/mechanic_lab_zombie_step_dust.gdshader")
const CAPACITY := 512
const ALPHA_SAMPLES := 54
const TICK_WRAP := 2048
const CAMERA_DISTANCE_SQUARED := 100.0 * 100.0

class Puff:
	var origin: Vector3
	var contact_tick: int
	var age := 0.0
	var lifetime: float
	var drag: float
	var cell: int
	var slot := -1

var _puffs: Array[Puff] = []
var _material: ShaderMaterial
var _random := RandomNumberGenerator.new()

func setup(texture: Texture2D, alpha: PackedFloat32Array, alpha_duration: float) -> bool:
	if alpha.size() != ALPHA_SAMPLES:
		return false
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("smoke_mask", texture)
	_material.set_shader_parameter("dust_tint", MovementDust.SURFACE_DUST.grass)
	_material.set_shader_parameter("alpha_curve", alpha)
	_material.set_shader_parameter("alpha_duration", alpha_duration)
	var quad := QuadMesh.new()
	quad.material = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	# Include the full flat Lab and room for the billboard at the edge.
	multimesh.custom_aabb = AABB(Vector3(-51.0, -8.0, -51.0), Vector3(102.0, 40.0, 102.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Reusing an instance slot must not blend with its previous puff.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_random.seed = 78105
	set_process(false)
	return true

func burst(ground_point: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(ground_point) > CAMERA_DISTANCE_SQUARED:
		return
	if _puffs.size() == CAPACITY:
		_puffs.pop_front()
	var puff := Puff.new()
	puff.origin = to_local(ground_point + Vector3.UP * 0.20)
	puff.contact_tick = Engine.get_physics_frames()
	puff.lifetime = _random.randf_range(0.80, 1.75)
	puff.drag = _random.randf_range(4.0, 10.0)
	puff.cell = MovementDust.FRAMES[_random.randi_range(0, MovementDust.FRAMES.size() - 1)]
	_puffs.append(puff)
	set_process(true)

func _process(_delta: float) -> void:
	# Use the same interpolated contact clock as the player's dust.
	var physics_tick := Engine.get_physics_frames()
	var fraction := 0.0 if Engine.is_in_physics_frame() else Engine.get_physics_interpolation_fraction() - 1.0
	var render_tick := float(physics_tick) + fraction
	var step := get_physics_process_delta_time()
	_material.set_shader_parameter("contact_clock", Vector3(physics_tick % TICK_WRAP, fraction, step))
	var count := 0
	for puff in _puffs:
		puff.age = maxf(render_tick - puff.contact_tick, 0.0) * step
		if puff.age >= puff.lifetime:
			continue
		if puff.slot != count:
			_puffs[count] = puff
			puff.slot = count
			multimesh.set_instance_transform(count, Transform3D(Basis.IDENTITY, puff.origin))
			multimesh.set_instance_custom_data(count,
				Color(puff.cell, puff.contact_tick % TICK_WRAP, puff.lifetime, puff.drag))
		count += 1
	_puffs.resize(count)
	multimesh.visible_instance_count = count
	set_process(count > 0)

func clear() -> void:
	_puffs.clear()
	multimesh.visible_instance_count = 0
	set_process(false)
