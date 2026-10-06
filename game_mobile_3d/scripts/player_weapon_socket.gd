extends BoneAttachment3D
const Profiles = preload("res://scripts/weapon_fire_profiles.gd")
## Runtime hold tuning only; authored meshes and marker locations stay intact.
const WEAPONS = [preload("res://assets/weapons/pistol_v4.glb"), preload("res://assets/weapons/m4a1_v4.glb"), preload("res://assets/weapons/shotgun_v4.glb")]
const HOLD_SCALES = [1.20, 1.12, 1.14]
## Socket space: +Y is barrel-forward, +Z is weapon-up (before Y-up undo).
const HOLD_OFFSETS = [Vector3(0.015, 0.025, 0.035), Vector3(0.210, 0.270, -0.120), Vector3(0.210, 0.340, 0.035)]
## Bring the rigid arm roots onto the front shoulder, without changing length.
const SHOULDER_OFFSETS = [Vector3.ZERO, Vector3(0, -0.020, 0.100), Vector3(0, 0, 0.120)]
const LOW_READY_FORWARD = [0.0, 0.030, 0.070]
const LOW_READY_SHOULDER_FORWARD = [0.0, 0.055, 0.070]
## Bring support toward the grip/receiver underside for a compact closed hold.
const SUPPORT_OFFSETS = [Vector3(0, -0.005, 0.010), Vector3(0, -0.018, 0.265), Vector3(0, -0.015, 0.250)]
## Opposite inner palm edges close around the gun, rather than stacking it on
## the arm centers. Preserve a small upper-edge inset for intentional overlap.
const MAIN_HAND_CONTACTS = [Vector3(-0.100, 0.594, 0.055), Vector3(-0.100, 0.656, 0.055), Vector3(-0.100, 0.670, 0.055)]
const SUPPORT_HAND_CONTACTS = [Vector3(0.100, 0.609, 0.055), Vector3(0.100, 0.635, 0.065), Vector3(0.100, 0.668, 0.065)]
var instances: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var grips: Array[Vector3] = []
var supports: Array[Vector3] = []
var equipped: int = 0
var hand_transforms: Array[Transform3D] = []
var back_socket: BoneAttachment3D
var hip_socket: BoneAttachment3D
var current_attachment: StringName = &"hand"

func _ready() -> void:
	bone_name = "WeaponSocket"
	for index in WEAPONS.size():
		var asset: PackedScene = WEAPONS[index]
		var instance := asset.instantiate() as Node3D
		# Socket stores a Blender-local frame; standalone GLB vertices/markers
		# are already Y-up. Undo that conversion once at the attachment boundary.
		instance.rotation.x = PI / 2.0
		add_child(instance)
		var grip := instance.find_child("Grip_Point", true, false) as Node3D
		var support := instance.find_child("Support_Hand_Point", true, false) as Node3D
		var grip_local := instance.to_local(grip.global_position)
		var support_local := instance.to_local(support.global_position)
		instance.scale = Vector3.ONE * HOLD_SCALES[index]
		# Scale around the grip, then move the grip out of the arm volume.
		instance.position = HOLD_OFFSETS[index] - instance.basis * grip_local
		grips.append(instance.transform * grip_local)
		supports.append(instance.transform * (support_local + SUPPORT_OFFSETS[index]))
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				if material: material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		instances.append(instance)
		hand_transforms.append(instance.transform)
		muzzles.append(instance.find_child("Muzzle_Point", true, false) as Node3D)
	equip(0)

func equip(index: int) -> void:
	# Return inactive instances to the original parent. Never duplicate weapons.
	for i in instances.size():
		if instances[i].get_parent() != self: instances[i].reparent(self, false)
		instances[i].transform = hand_transforms[i]
	current_attachment = &"hand"
	equipped = clampi(index, 0, 2)
	for i in instances.size(): instances[i].visible = i == equipped

func prepare_stow_sockets() -> void:
	if back_socket != null: return
	back_socket = BoneAttachment3D.new(); back_socket.name = "BackWeaponSocket"
	back_socket.bone_name = "Chest"; get_parent().add_child(back_socket)
	back_socket.position = Vector3(0, 0.10, -0.30)
	hip_socket = BoneAttachment3D.new(); hip_socket.name = "HipWeaponSocket_R"
	hip_socket.bone_name = "Hips"; get_parent().add_child(hip_socket)
	hip_socket.position = Vector3(-0.40, 0.18, -0.02)

func attach_equipped(attachment: StringName) -> void:
	prepare_stow_sockets()
	var destination: Node3D = self if attachment == &"hand" else (back_socket if attachment == &"back" else hip_socket)
	var instance := instances[equipped]
	if instance.get_parent() != destination: instance.reparent(destination, false)
	if attachment == &"hand": instance.transform = hand_transforms[equipped]
	else:
		# TEMPORARY preview placement; no procedural Draw/Holster trajectory.
		instance.position = Vector3.ZERO
		instance.rotation = Vector3(-PI/2, 0, deg_to_rad(-18.0) if attachment == &"back" else 0.0)
		instance.scale = Vector3.ONE * HOLD_SCALES[equipped]
	current_attachment = attachment

func set_equipped_visible(shown: bool) -> void:
	for i in instances.size(): instances[i].visible = shown and i == equipped

func muzzle_position() -> Vector3:
	return muzzles[equipped].global_position if muzzles[equipped] else global_position
