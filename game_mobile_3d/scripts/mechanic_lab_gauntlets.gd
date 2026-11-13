extends RefCounted
## Prime Enchanter's Gauntlets (MD2 Gauntlet_Unique1).

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const DIRECTORY := Source.EQUIPMENT + "Gauntlet/Gauntlet_Unique/"
const CLIPS := Source.ANIMATIONS + "Weapons_Melee/Fists/Combat/"
const LIBRARY := &"private_prime_gauntlets"
const AIR := "NativeGauntletAir"
const MESH_HASH := "c6097550b26db4cd467fe5ef20b8e7d025b475b6750f09c955c110d2bf8bd3de"
const TEXTURE_HASH := "a3ba68a9d67e02a48bd8c14f443245dc5a606cce1d8b0ac0617c3681fa611626"
const ICON_HASH := "85ef86c4b4548ea60bb89df54c776d9439946a63d6d1b4ab44b6dd948cafbc99"
const ATTACK_HASHES := [
	"dd8f9cbacf748ae8a2600c1c78b2278ad658867ef0be0e99cd456d3adc5bc128",
	"086b9b62585927336f23854db918aa1e0465560fb4990e8999da6d8f9c141961",
	"d6e5d53264106759f72c7b7c61944b7784a1c60974c70e4dd3f7bf3109771751",
]
const RECOVERY_HASHES := [
	"41879efecd28fa9ee4952714203bd3b46b7854c65b4599f31b269ffadb07d9ec",
	"70d0f6e7277388d42bfa2b8a7957b842efc663f35ecdb89f646671cae429ce7f",
	"1efdf14044079e3f33d7a8c1a2a7637916d0e7d9d3bd7e8b76ee7ca0150ee22c",
]
const ATTACK_FRAMES := [30, 33, 31]
const RECOVERY_FRAMES := [20, 19, 17]
const RATES := [2.0, 2.0, 1.1]
# First extension of each punching hand, sampled on the exported 30 Hz clips.
const CONTACT_FRAMES := [8, 12, 24]
const STRIKES := [
	{"damage": 10, "range_m": 2.4, "strength": 250.0, "angle": 15.0, "stagger": 14.0,
		"cone_degrees": 30.0, "cone_offset": -1.2, "cone_cutoff": 1.2, "splash_stagger": 0.5},
	{"damage": 11, "range_m": 2.4, "strength": 300.0, "angle": 15.0, "stagger": 14.0,
		"cone_degrees": 30.0, "cone_offset": -1.2, "cone_cutoff": 1.2, "splash_stagger": 0.5},
	{"damage": 14, "range_m": 2.75, "strength": 850.0, "angle": 25.0, "stagger": 20.0,
		"cone_degrees": 30.0, "cone_offset": -1.2, "cone_cutoff": 1.2, "splash_stagger": 0.5},
]
const AIR_STRIKE := {"damage": 24, "range_m": 2.5, "strength": 1150.0, "angle": 25.0,
	"stagger": 42.0, "splash_stagger": 0.5}
const AIR_OFFSET := 1.25
const AIR_CONTACT := 24.0 / 30.0
# The GLB has a separate edge surface but no export of its material instance
# parameters. Use the two colors sampled from the verified MD2 inventory icon.
const LEFT_GLOW := Color("#a9f4e6")
const RIGHT_GLOW := Color("#faf474")

static func icon() -> Texture2D:
	return Source.icon(DIRECTORY, "T_UI_Gauntlets_Unique_Icon", ICON_HASH)

static func load_mesh(actor: CharacterBody3D, root: String) -> Mesh:
	return Source.load_mesh(actor, root, DIRECTORY, "SM_Gauntlet_RL", MESH_HASH,
		"T_Gauntlet_Unique", TEXTURE_HASH)

static func with_edge_color(mesh: Mesh, color: Color) -> Mesh:
	var result := mesh.duplicate() as Mesh
	for surface in result.get_surface_count():
		var source := result.surface_get_material(surface) as BaseMaterial3D
		if source == null or not source.resource_name.begins_with("MI_Gauntlet_EdgeHighlight"):
			continue
		var edge := source.duplicate() as BaseMaterial3D
		edge.albedo_color = color
		edge.emission_enabled = true
		edge.emission = color
		edge.emission_energy_multiplier = 0.45
		result.surface_set_material(surface, edge)
	return result

static func combat_profile(root: String) -> Dictionary:
	var result := Source.profile()
	for i in ATTACK_FRAMES.size():
		var stem := "Player_GauntletsCombo_Attack%d" % (i + 1)
		var attack := Source.clip(root, CLIPS, stem, "NativeGauntletAttack%d" % (i + 1),
			ATTACK_FRAMES[i], ATTACK_HASHES[i], "attack")
		var recovery := Source.clip(root, CLIPS, stem + "Recovery", "NativeGauntletRecovery%d" % (i + 1),
			RECOVERY_FRAMES[i], RECOVERY_HASHES[i], "recovery")
		result.additional_clips.append_array([attack, recovery])
		var duration: float = attack.duration
		result.windows.append(Source.window(attack, recovery, RATES[i], CONTACT_FRAMES[i] / 30.0,
			duration - 4.0 / 30.0, duration - 2.0 / 30.0))
	result.additional_clips.append(Source.clip(root, CLIPS, "Player_Jump_Gauntlet-Attack_Heavy", AIR, 85,
		"71d4f86676b810fe68524fbe9e2a29dfd3ae51421d219f684b69392621fd16fe", "attack"))
	return result
