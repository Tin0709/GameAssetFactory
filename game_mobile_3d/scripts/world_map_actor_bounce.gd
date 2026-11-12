extends RefCounted
## Original diffuse return from WorldMap terrain, using the same sun visibility as mist.
const FOLDER := "godot_lab/world_map_unified_showcase_v001/actor_ground_bounce_phase_v001"
const PROOF_SHA := "e4f6b52fb89a65b4df0bbd7878e749d15ce86edb1d828e2f0759dac1505764f1"
const BASE_SHA := "fc69e0d8ce3c30269cdf9f34b5bb2872efccae3e7817b99fa7c00b7fd9644132"

var _origin: Vector3
var _step: Vector3
var _size: Vector3i
var _decode: float
var _proof: Dictionary
var _folder: String
var _data: PackedByteArray
var _valid: PackedByteArray
var _position := Vector3.INF
var _slots := Vector3.INF
var _samples: PackedVector3Array

func setup(level: Node3D, base_path: String) -> void:
	var air = level.showcase.directional_air
	if not air.available():
		return
	var folder: String = air.research_root.path_join(FOLDER)
	var path := folder.path_join("profile.private.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != PROOF_SHA or FileAccess.get_sha256(base_path) != BASE_SHA:
		return
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if proof.map_sha256 != FileAccess.get_sha256(level.DATA) or proof.input_atlas_sha256 != air.payload_sha256:
		return
	_origin = _vector(proof.origin)
	_step = _vector(proof.step)
	_size = Vector3i(_vector(proof.size))
	_decode = proof.decode_scale
	_folder = folder
	_proof = proof

func available() -> bool:
	return not _proof.is_empty()

func sample(position: Vector3, slots: Vector4) -> PackedVector3Array:
	if not available() or slots.w <= 0. or fade(position) <= 0. or not _load():
		return PackedVector3Array()
	var key := Vector3(slots.x, slots.y, slots.z)
	if position == _position and key == _slots:
		return _samples
	var result := PackedVector3Array()
	for height: float in [.25, 1., 1.8]:
		var values := _probe(position + Vector3.UP * height, int(slots.x), int(slots.y), slots.z)
		if values.size() != 6:
			result.clear()
			break
		result.append_array(values)
	_position = position
	_slots = key
	_samples = result
	return _samples

func fade(position: Vector3) -> float:
	var grid := (position - _origin) / _step
	var edge := minf(minf(grid.x, _size.x - 1 - grid.x), minf(grid.z, _size.z - 1 - grid.z))
	return smoothstep(0., 2., edge)

func _load() -> bool:
	if not _data.is_empty():
		return true
	var path := _folder.path_join("actor_bounce.private.u8")
	var valid_path := _folder.path_join("valid.private.u8")
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(valid_path) \
		or FileAccess.get_sha256(path) != _proof.sha256 or FileAccess.get_sha256(valid_path) != _proof.valid_sha256:
		_proof.clear()
		return false
	var values := FileAccess.get_file_as_bytes(path)
	var valid := FileAccess.get_file_as_bytes(valid_path)
	var count := _size.x * _size.y * _size.z
	if valid.size() != count or values.size() != count * 18 * int(_proof.directions):
		_proof.clear()
		return false
	_data = values
	_valid = valid
	return true

func _probe(position: Vector3, a: int, b: int, t: float) -> PackedVector3Array:
	var p := (position - _origin) / _step
	var result := PackedVector3Array()
	if not p.is_finite() or p.y < 0. or p.y > _size.y - 1:
		return result
	var lo := Vector3i(mini(floori(p.x), _size.x - 2), mini(floori(p.y), _size.y - 2), mini(floori(p.z), _size.z - 2))
	var f := p - Vector3(lo)
	var frame_size := _valid.size() * 18
	var total := 0.
	result.resize(6)
	for dx in 2:
		for dy in 2:
			for dz in 2:
				var i := ((lo.x + dx) * _size.y + lo.y + dy) * _size.z + lo.z + dz
				if _valid[i] == 0:
					continue
				var w := (f.x if dx else 1. - f.x) * (f.y if dy else 1. - f.y) * (f.z if dz else 1. - f.z)
				total += w
				for axis in 6:
					var offset := i * 18 + axis * 3
					var left := a * frame_size + offset
					var right := b * frame_size + offset
					var v := Vector3(lerpf(_data[left], _data[right], t), lerpf(_data[left+1], _data[right+1], t),
						lerpf(_data[left+2], _data[right+2], t))
					result[axis] += w * v
	if total <= .0001:
		return PackedVector3Array()
	for axis in 6:
		result[axis] *= _decode / total
	return result

func _vector(row: Array) -> Vector3:
	return Vector3(row[0], row[1], row[2])
