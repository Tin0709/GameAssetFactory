extends RefCounted
## Verified MD2 Curved Greatsword equipment and grounded clips for MechanicLab.

const Sword := preload("res://scripts/mechanic_lab_sword.gd")
const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Characters/Player/"
const CLIPS := SOURCE + "Animations/Weapons_Melee/2H_Medium/Combat/"
const LIBRARY := &"private_curved_greatsword"
const MESH_HASH := "00195143cc38f043e053cf4e9427597d711a34038d90fd088d55216fbb9120ed"
const TEXTURE_HASH := "56a9c441e36abb74df27c6bcdc392c6c55eac73c24e22ebfd8c01a5c627eb0e8"
const BLADE_BASE := Vector3(0.0, -0.44, 0.0)
const BLADE_TIP := Vector3(0.0, -1.811961, 0.30936)
const MEDIA_MANIFEST := "reports/prototype_sabre/private_curved_greatsword_media_manifest.json"
const PLAYBACK_RATE := 1.1
const ATTACK_FRAMES := [19.0, 25.0, 28.0]
const RECOVERY_DURATION := 0.5
# Weapon-tip landmarks measured in the source poses at 30 Hz.
# The finisher has two arcs. Use its second arc for the lab's single contact.
const CONTACT_FRAMES := [11.0, 14.0, 17.0]
const TRAIL_FRAMES := [Vector2(9, 13), Vector2(12, 17), Vector2(5, 21)]
const ATTACK_HASHES := [
	"377fb2081d1b2fabd3534138076aca4aead3dda6a81c8cd899fa8daba84b4ec9",
	"40e40cbe902bf73e0adf961ebb3265cc26a1f3289a97281b1f97cdcfca670d2b",
	"f3a921585929e301b0b0144eb0aef674e847202ce82e540ad2648ca99fefa5d1",
]
const RECOVERY_HASHES := [
	"befe2f8682b72bc1205c387b6abfcd4d9b9cabcf91cd551aa249a7cae7edba42",
	"887a19e50dafc565548a3bf2febadb9acc4d9320a45f3babcdb1cabf0a7cc869",
	"e165c68502bcbb88a295ec86029651353481e13bd3187be826a636f8f9b201d8",
]

static func load_mesh(actor: CharacterBody3D, research_root: String) -> Mesh:
	return Sword.load_verified_mesh(actor, research_root, SOURCE + "Equipment/Weapons/CurvedGreatsword/",
		"CurvedGreatsword", MESH_HASH, TEXTURE_HASH)

static func combat_profile(research_root: String) -> Dictionary:
	var profile := {
		"schema": "md2-private-sabre-combat/1",
		"input": {"ground_policy": "live_hold", "event_evaluation_hz": 60.0},
		"leg_branches": ["J_L_Leg", "J_R_Leg"], "blend_seconds": 0.08,
		"windows": [], "additional_clips": [],
	}
	for i in ATTACK_FRAMES.size():
		var stem := "Player_CurvedGreatswordCombo_Attack%d" % (i + 1)
		var attack := "NativeCurvedAttack%d" % (i + 1)
		var recovery := "NativeCurvedRecovery%d" % (i + 1)
		var duration: float = ATTACK_FRAMES[i] / 30.0
		var trail := [TRAIL_FRAMES[i].x / 30.0, TRAIL_FRAMES[i].y / 30.0]
		profile.additional_clips.append({
			"path": ReferenceAudio.resolve_private_file(research_root, CLIPS + stem + ".glb"),
			"semantic": attack, "source_name": stem, "sha256": ATTACK_HASHES[i],
			"duration": duration, "loop": false, "category": "attack", "vfx_window": trail,
		})
		profile.additional_clips.append({
			"path": ReferenceAudio.resolve_private_file(research_root, CLIPS + stem + "Recovery.glb"),
			"semantic": recovery, "source_name": stem + "Recovery", "sha256": RECOVERY_HASHES[i],
			"duration": RECOVERY_DURATION, "loop": false, "category": "recovery", "vfx_window": [0.0, 0.0],
		})
		profile.windows.append({
			"rate": PLAYBACK_RATE, "resume": duration - 2.0 / 30.0, "chain": duration,
			"melee": CONTACT_FRAMES[i] / 30.0, "trail_window": trail,
			"attack_duration": duration, "recovery_duration": RECOVERY_DURATION,
			"attack_key": attack, "recovery_key": recovery,
			"attack_source": stem, "recovery_source": stem + "Recovery",
		})
	return profile
