extends Resource
## A map-owned signed sky exposure field with 128 as the neutral code.

@export var texture: Texture2D
@export var origin_xz := Vector2.ZERO
@export_range(.1, 2.) var spacing_m := .25
@export var surface_y := 0.
@export var layout_sha256 := ""


func matches_layout(path: String) -> bool:
	return texture != null and texture.get_width() >= 2 and texture.get_height() >= 2 \
		and origin_xz.is_finite() and is_finite(surface_y) \
		and spacing_m >= .1 and spacing_m <= 2. \
		and layout_sha256.length() == 64 and FileAccess.get_sha256(path) == layout_sha256


func bounds() -> Vector4:
	return Vector4(origin_xz.x, origin_xz.y, spacing_m, surface_y)


func sample_exposure(image: Image, point: Vector2) -> float:
	var sample := (point - origin_xz) / spacing_m
	var last := image.get_size() - Vector2i.ONE
	if sample.x < 0. or sample.y < 0. or sample.x > last.x or sample.y > last.y:
		return 0.
	var first := Vector2i(sample.floor())
	var next := (first + Vector2i.ONE).min(last)
	var fraction := sample - Vector2(first)
	var north := lerpf(image.get_pixel(first.x, first.y).r, image.get_pixel(next.x, first.y).r, fraction.x)
	var south := lerpf(image.get_pixel(first.x, next.y).r, image.get_pixel(next.x, next.y).r, fraction.x)
	return (lerpf(north, south, fraction.y) * 255. - 128.) * (1.10 / 127.)
