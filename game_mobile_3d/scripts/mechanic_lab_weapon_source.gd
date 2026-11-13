extends RefCounted
## External MD2 assets shared by the two requested MechanicLab weapon adapters.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/"
const PLAYER := SOURCE + "Art/Characters/Player/"
const ANIMATIONS := PLAYER + "Animations/"
const EQUIPMENT := PLAYER + "Equipment/Weapons/"
const AUDIO := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood/Items/Weapons/"

static func research_root() -> String:
	var configured := OS.get_environment("MD2_RESEARCH_ROOT")
	return OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research") if configured.is_empty() else configured

static func verified_path(root: String, relative: String, hash_value: String) -> String:
	if not OS.has_feature("editor"):
		return ""
	var path := ReferenceAudio.resolve_private_file(root, relative)
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != hash_value:
		return ""
	return path

static func load_mesh(actor: CharacterBody3D, root: String, directory: String, mesh_name: String,
		mesh_hash: String, texture_name: String, texture_hash: String) -> Mesh:
	var path := verified_path(root, directory + mesh_name + ".glb", mesh_hash)
	if path.is_empty() or verified_path(root, directory + texture_name + ".png", texture_hash).is_empty():
		return null
	var model: Node3D = actor.load_private_model(path)
	if model == null:
		return null
	var node := model.find_child(mesh_name, true, false) as MeshInstance3D
	var mesh := node.mesh if node != null else null
	model.free()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var primary := mesh.surface_get_material(0) as BaseMaterial3D
	if primary == null or primary.albedo_texture == null:
		return null
	for index in mesh.get_surface_count():
		var material := mesh.surface_get_material(index) as BaseMaterial3D
		if material != null:
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mesh

static func icon(directory: String, stem: String, hash_value: String) -> Texture2D:
	var path := verified_path(research_root(), directory + stem + ".png", hash_value)
	if path.is_empty():
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	image.resize(24, 24, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func clip(root: String, directory: String, stem: String, semantic: String, frames: int,
		hash_value: String, category: String, loop := false) -> Dictionary:
	return {
		"path": ReferenceAudio.resolve_private_file(root, directory + stem + ".glb"),
		"semantic": semantic, "source_name": stem, "sha256": hash_value,
		"duration": frames / 30.0, "category": category, "loop": loop, "vfx_window": [0.0, 0.0],
	}

static func profile() -> Dictionary:
	return {
		"schema": "md2-private-sabre-combat/1",
		"input": {"ground_policy": "live_hold", "event_evaluation_hz": 60.0},
		"leg_branches": ["J_L_Leg", "J_R_Leg"], "blend_seconds": 0.08,
		"windows": [], "additional_clips": [],
	}

static func window(attack: Dictionary, recovery: Dictionary, rate: float, contact: float,
		resume: float, chain: float) -> Dictionary:
	return {
		"rate": rate, "resume": resume, "chain": chain, "melee": contact, "trail_window": [0.0, 0.0],
		"attack_duration": attack.duration, "recovery_duration": recovery.duration,
		"attack_key": attack.semantic, "recovery_key": recovery.semantic,
		"attack_source": attack.source_name, "recovery_source": recovery.source_name,
	}
