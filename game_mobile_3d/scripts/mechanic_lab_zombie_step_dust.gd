extends MultiMeshInstance3D

const MovementDust := preload("res://scripts/mechanic_lab_movement_dust.gd")
const SHADER := preload("res://materials/mechanic_lab_zombie_step_dust.gdshader")
const CAPACITY := 512
const ALPHA_SAMPLES := 54
const TICK_WRAP := 2048
const INSTANCE_FLOATS := 16
const BUFFER_UPLOAD_MIN := 48
# Half-open pixel bounds of the nonzero alpha in the verified smoke atlas.
const SMOKE_CELL_BOUNDS := {
	0: Vector4(4, 5, 12, 14),
	9: Vector4(4, 3, 11, 11),
	10: Vector4(3, 3, 13, 12),
	16: Vector4(4, 5, 12, 14),
	24: Vector4(4, 6, 12, 13),
	25: Vector4(2, 4, 14, 13),
}

class Puff:
	var origin: Vector3
	var contact_tick: int
	var age := 0.0
	var lifetime: float
	var drag: float
	var cell: int
	var slot := -1

# Spawn order handles eviction. The draw slots can move independently.
var _puffs: Array[Puff] = []
var _rendered: Array[Puff] = []
var _vacant_slots := PackedInt32Array()
var _instance_buffer := PackedFloat32Array()
var _material: ShaderMaterial
var _random := RandomNumberGenerator.new()

func setup(texture: Texture2D, alpha: PackedFloat32Array, alpha_duration: float,
		verified_smoke_atlas := false) -> bool:
	if alpha.size() != ALPHA_SAMPLES:
		return false
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("smoke_mask", texture)
	if verified_smoke_atlas:
		var cell_bounds := PackedVector4Array()
		cell_bounds.resize(32)
		cell_bounds.fill(Vector4(0, 0, 1, 1))
		for cell: int in SMOKE_CELL_BOUNDS:
			cell_bounds[cell] = SMOKE_CELL_BOUNDS[cell] / 16.0
		_material.set_shader_parameter("cell_bounds", cell_bounds)
		_material.set_shader_parameter("crop_smoke_atlas", true)
	_material.set_shader_parameter("dust_tint", MovementDust.SURFACE_DUST.grass)
	_material.set_shader_parameter("alpha_curve", alpha)
	_material.set_shader_parameter("alpha_duration", alpha_duration)
	_material.set_shader_parameter("source_step_seconds", MovementDust.SOURCE_PHYSICS_STEP)
	var range_m := MovementDust.SOURCE_CAMERA_RANGE
	_material.set_shader_parameter("camera_range_squared", range_m * range_m)
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
	if _puffs.size() == CAPACITY:
		var oldest: Puff = _puffs.pop_front()
		if oldest.slot >= 0:
			_vacant_slots.append(oldest.slot)
			oldest.slot = -1
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
	for index in _puffs.size():
		var puff := _puffs[index]
		puff.age = maxf(render_tick - puff.contact_tick, 0.0) * step
		if puff.age >= puff.lifetime:
			if puff.slot >= 0:
				_vacant_slots.append(puff.slot)
				puff.slot = -1
			continue
		if index != count:
			_puffs[count] = puff
		count += 1
	if _puffs.size() != count:
		_puffs.resize(count)

	if not _vacant_slots.is_empty():
		# Rebuild the draw buffer when at least half its slots expire or are evicted.
		if _vacant_slots.size() * 2 >= _rendered.size():
			_rebuild_slots(count)
		else:
			_fill_vacant_slots()
		_vacant_slots.clear()

	# Newly spawned puffs are at the end in spawn order.
	for index in range(_rendered.size(), count):
		var puff := _puffs[index]
		_upload(puff, index)
		_rendered.append(puff)
	if multimesh.visible_instance_count != count:
		multimesh.visible_instance_count = count
	if count == 0:
		set_process(false)

func _rebuild_slots(count: int) -> void:
	if count >= BUFFER_UPLOAD_MIN:
		# MultiMesh rows are three transform rows followed by custom data.
		if _instance_buffer.is_empty():
			_instance_buffer.resize(CAPACITY * INSTANCE_FLOATS)
			for index in CAPACITY:
				var offset := index * INSTANCE_FLOATS
				_instance_buffer[offset] = 1.0
				_instance_buffer[offset + 5] = 1.0
				_instance_buffer[offset + 10] = 1.0
		for index in count:
			var puff := _puffs[index]
			puff.slot = index
			var offset := index * INSTANCE_FLOATS
			_instance_buffer[offset + 3] = puff.origin.x
			_instance_buffer[offset + 7] = puff.origin.y
			_instance_buffer[offset + 11] = puff.origin.z
			_instance_buffer[offset + 12] = puff.cell
			_instance_buffer[offset + 13] = puff.contact_tick % TICK_WRAP
			_instance_buffer[offset + 14] = puff.lifetime
			_instance_buffer[offset + 15] = puff.drag
		multimesh.buffer = _instance_buffer
	else:
		for index in count:
			var puff := _puffs[index]
			if puff.slot != index:
				_upload(puff, index)
	_rendered.assign(_puffs)

func _fill_vacant_slots() -> void:
	# All dust billboards use the same tint, so a survivor can fill a hole.
	for slot in _vacant_slots:
		while not _rendered.is_empty() and _rendered.back().slot < 0:
			_rendered.pop_back()
		if slot < _rendered.size():
			var last: Puff = _rendered.pop_back()
			_rendered[slot] = last
			_upload(last, slot)

func _upload(puff: Puff, slot: int) -> void:
	puff.slot = slot
	multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, puff.origin))
	multimesh.set_instance_custom_data(slot,
		Color(puff.cell, puff.contact_tick % TICK_WRAP, puff.lifetime, puff.drag))

func clear() -> void:
	_puffs.clear()
	_rendered.clear()
	_vacant_slots.clear()
	multimesh.visible_instance_count = 0
	set_process(false)
