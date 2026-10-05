extends Label3D
## One node per accepted hit; detached from the actor so lethal numbers survive.
const DURATION := 0.65
var elapsed := 0.0
var amount := 0
var player_hit := false
static var number_font: FontVariation

func _ready() -> void:
	text = str(amount)
	if number_font == null:
		number_font = FontVariation.new()
		number_font.base_font = ThemeDB.fallback_font
		number_font.variation_embolden = 0.6
	font = number_font
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	font_size = 48
	pixel_size = 0.0045
	outline_size = 9
	outline_modulate = Color(0.06, 0.045, 0.035, 1)
	modulate = Color(1, 0.40, 0.30) if player_hit else Color(1, 0.96, 0.78)
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	elapsed += delta
	position.y += delta * 0.55
	modulate.a = clampf((DURATION - elapsed) / 0.25, 0.0, 1.0)
	outline_modulate.a = modulate.a
	if elapsed >= DURATION: queue_free()
