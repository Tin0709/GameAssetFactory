extends RefCounted
## Private Sword equipment and timing for MechanicLab.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const ASSET_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Characters/Player/Equipment/Weapons/Sword/"
const MESH_HASH := "edfc3fb347433f2d7280be333662eb98c42c16249ff53a0392f71f60c40c1686"
const TEXTURE_HASH := "54ffa5916a618407d5b50faecce35c01c8626ffa3537c7078d0b5d9ea463c737"
const BLADE_BASE := Vector3(0.0, -0.3094, 0.0)
const BLADE_TIP := Vector3(0.0, -1.104854, 0.0)
const MEDIA_MANIFEST := "reports/prototype_sabre/private_sword_media_manifest.json"
const AUDIO_ALIASES := {
	"Attack1": "SwordAttack1", "Attack2": "SwordAttack2", "Attack3": "SwordAttack3",
	"AirAttack": "SwordAirAttack",
}

static func load_mesh(actor: CharacterBody3D, research_root: String) -> Mesh:
	var path := ReferenceAudio.resolve_private_file(research_root, ASSET_DIR + "SM_Sword.glb")
	var texture := ReferenceAudio.resolve_private_file(research_root, ASSET_DIR + "T_Sword.png")
	if path.is_empty() or texture.is_empty() or not FileAccess.file_exists(path) or not FileAccess.file_exists(texture):
		return null
	if FileAccess.get_sha256(path) != MESH_HASH or FileAccess.get_sha256(texture) != TEXTURE_HASH:
		return null
	var model: Node3D = actor.load_private_model(path)
	if model == null:
		return null
	var node := model.find_child("SM_Sword", true, false) as MeshInstance3D
	var mesh := node.mesh if node != null else null
	model.free()
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		return null
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mesh

static func combat_profile(sabre: Dictionary, clips: Dictionary) -> Dictionary:
	var result := sabre.duplicate(true)
	# The first two clips are shared by both weapon montages. The Sword's
	# thrust reaches its furthest visible extension at source frame 12.
	result.windows[0].rate = 1.0
	result.windows[1].rate = 1.0
	result.windows[2] = {
		"rate": 1.4, "resume": 13.0 / 30.0, "chain": 19.0 / 30.0,
		"melee": 12.0 / 30.0, "trail_window": [11.0 / 30.0, 15.0 / 30.0],
		"attack_duration": clips.Attack3.duration, "recovery_duration": clips.Recovery3.duration,
		"attack_source": clips.Attack3.source_name, "recovery_source": clips.Recovery3.source_name,
		"attack_key": "Attack3", "recovery_key": "Recovery3",
	}
	return result
