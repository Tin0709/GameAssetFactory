extends MultiMeshInstance3D
## Eight original cubes, one instanced draw; no textures, lights or physics.
const COUNT := 8
const DURATION := 0.70
const SHADER = preload("res://materials/block_smoke.gdshader")
static var cube: BoxMesh
static var smoke_material: ShaderMaterial
var elapsed := 0.0
var origins: Array[Vector3] = []
var velocities: Array[Vector3] = []
var bases: Array[Basis] = []
var sizes: Array[float] = []
var shades: Array[float] = []

func _ready() -> void:
	if cube == null:
		cube = BoxMesh.new()
		cube.size = Vector3.ONE * 0.16
		smoke_material = ShaderMaterial.new()
		smoke_material.shader = SHADER
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = COUNT
	material_override = smoke_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in COUNT:
		var angle := TAU * float(i) / COUNT + randf_range(-0.20, 0.20)
		var outward := Vector3(cos(angle), 0, sin(angle))
		origins.append(outward * randf_range(0.04, 0.18) + Vector3.UP * randf_range(-0.12, 0.20))
		velocities.append(outward * randf_range(0.35, 0.65) + Vector3.UP * randf_range(0.45, 0.85))
		bases.append(Basis.from_euler(Vector3(randf(), randf(), randf()) * 0.7))
		sizes.append(randf_range(0.70, 1.25))
		shades.append(randf_range(0.82, 1.0))
	_update_pieces()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	_update_pieces()

func _update_pieces() -> void:
	var progress := elapsed / DURATION
	for i in COUNT:
		var piece_basis := bases[i].scaled(Vector3.ONE * sizes[i] * (1.0 + 0.55 * progress))
		multimesh.set_instance_transform(i, Transform3D(piece_basis, origins[i] + velocities[i] * elapsed))
		multimesh.set_instance_color(i, Color(shades[i], shades[i], shades[i], clampf((1.0 - progress) / 0.65, 0.0, 1.0)))
