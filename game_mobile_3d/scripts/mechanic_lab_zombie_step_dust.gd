extends MultiMeshInstance3D

const MovementDust := preload("res://scripts/mechanic_lab_movement_dust.gd")
const SHADER := preload("res://materials/mechanic_lab_zombie_step_dust.gdshader")
const CAPACITY := 512
const CAMERA_DISTANCE_SQUARED := 100.0 * 100.0

class Puff:
	var origin: Vector3
	var contact_tick: int
	var lifetime: float
	var drag: float
	var cell: Vector2

var _puffs: Array[Puff] = []
var _alpha: PackedFloat32Array
var _alpha_duration: float
var _random := RandomNumberGenerator.new()

func setup(texture: Texture2D, alpha: PackedFloat32Array, alpha_duration: float) -> bool:
	if alpha.is_empty():
		return false
	_alpha = alpha
	_alpha_duration = alpha_duration
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("smoke_mask", texture)
	material.set_shader_parameter("dust_tint", MovementDust.SURFACE_DUST.grass)
	var quad := QuadMesh.new()
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	# Include the full flat Lab and room for the billboard at the edge.
	multimesh.custom_aabb = AABB(Vector3(-51.0, -8.0, -51.0), Vector3(102.0, 40.0, 102.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var frame: int = MovementDust.FRAMES[_random.randi_range(0, MovementDust.FRAMES.size() - 1)]
	puff.cell = Vector2(frame % 8, floori(float(frame) / 8.0))
	_puffs.append(puff)
	set_process(true)

func _process(_delta: float) -> void:
	# Use the same interpolated contact clock as the player's dust.
	var render_tick := float(Engine.get_physics_frames())
	if not Engine.is_in_physics_frame():
		render_tick += Engine.get_physics_interpolation_fraction() - 1.0
	var step := get_physics_process_delta_time()
	var count := 0
	for puff in _puffs:
		var age := maxf(render_tick - puff.contact_tick, 0.0) * step
		if age >= puff.lifetime:
			continue
		_puffs[count] = puff
		var point := puff.origin + Vector3.UP * MovementDust.source_step_height(age, puff.drag)
		var opacity := MovementDust._sample_curve(_alpha, age / (puff.lifetime * _alpha_duration))
		multimesh.set_instance_transform(count, Transform3D(Basis.IDENTITY, point))
		multimesh.set_instance_custom_data(count, Color(puff.cell.x, puff.cell.y, opacity, 0.0))
		count += 1
	_puffs.resize(count)
	multimesh.visible_instance_count = count
	set_process(count > 0)

func clear() -> void:
	_puffs.clear()
	multimesh.visible_instance_count = 0
	set_process(false)
