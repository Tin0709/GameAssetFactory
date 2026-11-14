extends Resource
## Map-authored area and opening used by the local diffuse return.

@export var center_xz := Vector2.ZERO
@export var radii_m := Vector2(8., 8.)
@export var opening_world := Vector3.ZERO
static var _owner: WeakRef

static func claim(publisher: Node) -> void:
	_owner = weakref(publisher)
	RenderingServer.global_shader_parameter_set("gaf_local_diffuse_source", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_local_diffuse_ambient", Vector3.ZERO)

static func owns(publisher: Node) -> bool:
	return _owner != null and _owner.get_ref() == publisher

static func release(publisher: Node) -> void:
	if owns(publisher):
		RenderingServer.global_shader_parameter_set("gaf_local_diffuse_source", Vector4.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_local_diffuse_ambient", Vector3.ZERO)
		_owner = null

func is_valid() -> bool:
	return center_xz.is_finite() and radii_m.is_finite() and opening_world.is_finite() \
		and radii_m.x >= .1 and radii_m.y >= .1

func bounds() -> Vector4:
	return Vector4(center_xz.x, center_xz.y, radii_m.x, radii_m.y)

func source(gain: float) -> Vector4:
	return Vector4(opening_world.x, opening_world.y, opening_world.z, gain)
