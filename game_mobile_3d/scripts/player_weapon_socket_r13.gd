extends "res://scripts/player_weapon_socket.gd"
## Exact approved geometry/mounts. No legacy percentages or contact adjustments.
const ASSETS_R13 = [preload("res://assets/characters/r13/pistol.glb"), preload("res://assets/characters/r13/rifle.glb"), preload("res://assets/characters/r13/shotgun.glb")]
const KINDS_R13 = ["Pistol","Rifle","Shotgun"]
var r13_data: Dictionary
var r13_stow_mounts: Array[Transform3D] = []

static func from_rows(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))

func _ready() -> void:
	bone_name = "WeaponSocket"
	r13_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/r13/source.json"))
	for i in 3:
		var instance: Node3D = ASSETS_R13[i].instantiate()
		add_child(instance)
		var data: Dictionary = r13_data.weapons[KINDS_R13[i]]
		var mount := from_rows(data.carrier_mount)
		instance.transform = mount
		instances.append(instance); hand_transforms.append(mount)
		r13_stow_mounts.append(from_rows(data.stow_mount))
		var grip: Node3D = instance.find_child("*Grip_Point*",true,false)
		var support: Node3D = instance.find_child("*Support_Hand_Point*",true,false)
		grips.append(instance.transform * instance.to_local(grip.global_position))
		supports.append(instance.transform * instance.to_local(support.global_position))
		muzzles.append(instance.find_child("*Muzzle_Point*",true,false))
		for mesh: MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				if material: material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	equip(0)

func prepare_stow_sockets() -> void:
	if back_socket != null:return
	back_socket=BoneAttachment3D.new();back_socket.name="BackWeaponSocket";back_socket.bone_name="Chest";get_parent().add_child(back_socket)
	# Source right-hip mount is in Chest space; preserve its approved body-follow.
	hip_socket=BoneAttachment3D.new();hip_socket.name="HipWeaponSocket_R";hip_socket.bone_name="Chest";get_parent().add_child(hip_socket)

func prepare_transport_socket(_endpoint: Transform3D) -> void:
	prepare_stow_sockets()
	carrier_socket=BoneAttachment3D.new();carrier_socket.name="WeaponCarrierSocket";carrier_socket.bone_name="WeaponCarrier";get_parent().add_child(carrier_socket)

func prepare_draw_mounts(_carrier: Transform3D, _hand: Transform3D) -> void: pass

func sync_transport_sockets() -> void:
	on_skeleton_update();carrier_socket.on_skeleton_update();back_socket.on_skeleton_update();hip_socket.on_skeleton_update()

func transport_canonical() -> Transform3D: return hand_transforms[equipped]

func end_transport(keep_global: bool) -> void:
	var destination: Node3D = hip_socket if equipped==0 else back_socket
	if keep_global: _transport_reparent(destination,"carrier_to_hip" if equipped==0 else "carrier_to_back")
	else: instances[equipped].reparent(destination,false)
	transport_release=instances[equipped].transform
	current_attachment=&"hip" if equipped==0 else &"back"

func update_transport(time: float, release_time: float, duration: float, blend_in: float) -> void:
	if current_attachment==&"carrier":
		instances[equipped].transform=transport_entry.interpolate_with(hand_transforms[equipped],smoothstep(0.0,blend_in,time))
	elif current_attachment in [&"back",&"hip"]:
		instances[equipped].transform=transport_release.interpolate_with(r13_stow_mounts[equipped],smoothstep(release_time,duration,time))

func update_draw_transport(time: float, _catch: float, _ready: float) -> void:
	if current_attachment==&"carrier":
		instances[equipped].transform=draw_mount_entry.interpolate_with(hand_transforms[equipped],smoothstep(draw_mount_started,draw_mount_started+0.08,time))

func attach_equipped(attachment: StringName) -> void:
	prepare_stow_sockets()
	var destination: Node3D=self if attachment==&"hand" else (hip_socket if attachment==&"hip" else back_socket)
	if instances[equipped].get_parent()!=destination:instances[equipped].reparent(destination,false)
	instances[equipped].transform=hand_transforms[equipped] if attachment==&"hand" else r13_stow_mounts[equipped]
	current_attachment=attachment
