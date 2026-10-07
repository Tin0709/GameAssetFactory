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
var carrier_socket: BoneAttachment3D
var back_mount: Node3D
var transport_entry := Transform3D.IDENTITY
var transport_release := Transform3D.IDENTITY
var transport_jumps: Array[Dictionary] = []
var draw_mount_entry := Transform3D.IDENTITY
var draw_mount_started := 0.0
var draw_hand_entry := Transform3D.IDENTITY
var draw_ready_mounts: Array[Transform3D] = []
## Broader Shotgun receiver/stock needs additional clearance along transport
## +Y (barrel-forward) and +Z (weapon-up). M4 mount and shared motion unchanged.
const SHOTGUN_TRANSPORT_OFFSET = Vector3(0, 0.125, 0.025)
## Chest space: stock toward upper-right, barrel toward lower-left. Asset -Z
## is barrel-forward; its broad face stays parallel to the back. Same socket
## and authored transport, with only a category-specific final visual mount.
const BACK_CARRY_ANGLE = 20.0
const BACK_CARRY_ORIGINS = [Vector3.ZERO, Vector3(0.025, 0.110, -0.180), Vector3(0.005, 0.095, -0.177)]

func back_canonical() -> Transform3D:
	var angle := deg_to_rad(BACK_CARRY_ANGLE)
	var stock_axis := Vector3(cos(angle), sin(angle), 0)
	var weapon_up := Vector3(sin(angle), -cos(angle), 0)
	var basis := Basis(weapon_up.cross(stock_axis), weapon_up, stock_axis).scaled(Vector3.ONE * HOLD_SCALES[equipped])
	return back_mount.transform.affine_inverse() * Transform3D(basis, BACK_CARRY_ORIGINS[equipped])

func prepare_transport_socket(endpoint: Transform3D) -> void:
	prepare_stow_sockets()
	carrier_socket = BoneAttachment3D.new(); carrier_socket.name = "WeaponCarrierSocket"
	carrier_socket.bone_name = "WeaponCarrier"; get_parent().add_child(carrier_socket)
	back_mount = Node3D.new(); back_mount.name = "BackWeaponMount"
	back_socket.add_child(back_mount); back_mount.transform = endpoint

func sync_transport_sockets() -> void:
	# Native attachment refresh, only while the authored transition is active.
	carrier_socket.on_skeleton_update()
	back_socket.on_skeleton_update()

func transport_canonical() -> Transform3D:
	var basis := Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3.ONE * HOLD_SCALES[equipped])
	# Grip_Point may be offset in the original standalone asset.
	var grip_local := hand_transforms[equipped].affine_inverse() * grips[equipped]
	var clearance := SHOTGUN_TRANSPORT_OFFSET if equipped == 2 else Vector3.ZERO
	return Transform3D(basis, clearance - basis * grip_local)

func _transport_reparent(destination: Node3D, label: String) -> void:
	var instance := instances[equipped]; var before := instance.global_transform
	instance.reparent(destination, true)
	transport_jumps.append({"handoff": label, "position_m": before.origin.distance_to(instance.global_position), "rotation_rad": before.basis.get_rotation_quaternion().angle_to(instance.global_basis.get_rotation_quaternion()), "instance": instance.get_instance_id()})
	if transport_jumps.size()>32: transport_jumps.pop_front()

func begin_transport() -> void:
	_transport_reparent(carrier_socket, "hand_to_carrier")
	transport_entry = instances[equipped].transform
	current_attachment = &"carrier"

func begin_draw_transport(time: float) -> void:
	_transport_reparent(carrier_socket, "back_to_carrier")
	draw_mount_entry = instances[equipped].transform
	draw_mount_started = time
	current_attachment = &"carrier"

func prepare_draw_mounts(carrier_endpoint: Transform3D, hand_endpoint: Transform3D) -> void:
	for hand_transform in hand_transforms:
		draw_ready_mounts.append(carrier_endpoint.affine_inverse() * hand_endpoint * hand_transform)

func update_draw_transport(time: float, catch_time: float, ready_time: float) -> void:
	if current_attachment != &"carrier": return
	# Preserve the release frame, then reconcile category-specific back/grip
	# mounting over 80 ms. The authored Carrier supplies the entire trajectory.
	var canonical := transport_canonical()
	if equipped == 2: canonical.origin.x -= 0.01 # Draw-only stock/head clearance.
	var pose := draw_mount_entry.interpolate_with(canonical, smoothstep(draw_mount_started, draw_mount_started + 0.08, time))
	# Shotgun's existing transport clearance differs from its READY visual mount.
	# Reconcile only that weapon offset during the authored catch-to-ready settle.
	if equipped == 2:
		pose = pose.interpolate_with(draw_ready_mounts[equipped], smoothstep(catch_time, ready_time, time))
	instances[equipped].transform = pose

func end_draw_transport() -> void:
	_transport_reparent(self, "carrier_to_hand" if current_attachment == &"carrier" else "draw_cancel_back_to_hand")
	draw_hand_entry = instances[equipped].transform
	current_attachment = &"hand"

func finish_draw_mount(weight: float) -> void:
	instances[equipped].transform = draw_hand_entry.interpolate_with(hand_transforms[equipped], weight)

func end_transport(keep_global: bool) -> void:
	if back_mount == null: return
	if keep_global: _transport_reparent(back_mount, "carrier_to_back")
	else: instances[equipped].reparent(back_mount, false)
	transport_release = instances[equipped].transform
	current_attachment = &"back"

func update_transport(time: float, release_time: float, duration: float, blend_in: float) -> void:
	var canonical := transport_canonical()
	if current_attachment == &"carrier":
		var authored := transport_entry.interpolate_with(canonical, smoothstep(0.0, blend_in, time))
		# Settle the visual only after the early shoulder transport. The target
		# follows Chest; interpolation runs through release, keeping the approved
		# event time and global-preserving reparent. No authored bone is changed.
		var target := carrier_socket.global_transform.affine_inverse() * back_mount.global_transform * back_canonical()
		var settling := smoothstep(release_time - 0.30, duration, time)
		var pose := authored.interpolate_with(target, settling)
		# Stock sweeps beside the head while rotating. Temporary back clearance
		# vanishes at both ends; the bulkier Shotgun uses the larger allowance.
		var clearance := 0.085 if equipped == 2 else 0.060
		var sweep_clearance := Vector3(-0.035 if equipped == 1 else 0.0, 0, -clearance) * sin(PI * settling)
		pose.origin += carrier_socket.global_basis.inverse() * back_socket.global_basis * sweep_clearance
		instances[equipped].transform = pose
	elif current_attachment == &"back":
		instances[equipped].transform = transport_release.interpolate_with(back_canonical(), smoothstep(release_time, duration, time))

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
	if attachment == &"back" and back_mount != null:
		instances[equipped].reparent(back_mount, false)
		instances[equipped].transform = back_canonical()
		current_attachment = attachment
		return
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
