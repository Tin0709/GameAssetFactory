extends Node3D
## Lazy overhead UI; actor-owned timer, shared resources, no per-hit tree scans.
const NUMBER = preload("res://scripts/damage_number.gd")
const BAR_SHADER = preload("res://materials/overhead_health.gdshader")
const SHOW_TIME := 1.5
const FADE_TIME := 0.25
static var bar_mesh: QuadMesh
static var bar_material: ShaderMaterial
var bar: MeshInstance3D
var remaining := 0.0
var player_hit := false
var number_serial := 0

func _ready() -> void:
	set_process(false)

func show_hit(amount: int, hp: int, maximum: int, effects: Node3D) -> void:
	if bar == null:
		if bar_mesh == null:
			bar_mesh = QuadMesh.new()
			bar_mesh.size = Vector2(0.66, 0.095)
			bar_material = ShaderMaterial.new()
			bar_material.shader = BAR_SHADER
		bar = MeshInstance3D.new()
		bar.name = "OverheadHealth"
		bar.mesh = bar_mesh
		bar.material_override = bar_material
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
		bar.position.y = 2.04
	bar.set_instance_shader_parameter("health_ratio", clampf(float(hp) / maxi(1, maximum), 0.0, 1.0))
	bar.set_instance_shader_parameter("bar_opacity", 1.0)
	bar.show()
	remaining = SHOW_TIME
	set_process(true)
	var number := NUMBER.new()
	number.name = "DamageNumber"
	number.amount = amount
	number.player_hit = player_hit
	# Alternate bounded lateral slots to separate rapid hits without RNG per hit.
	var offset := Vector3(0.14 * (number_serial % 3 - 1), 2.23, 0)
	number_serial += 1
	var origin := global_position + offset
	var container: Node3D = effects if is_instance_valid(effects) else self
	container.add_child(number)
	number.top_level = true
	number.global_position = origin

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	bar.set_instance_shader_parameter("bar_opacity", minf(1.0, remaining / FADE_TIME))
	if remaining == 0.0:
		bar.hide()
		set_process(false)
