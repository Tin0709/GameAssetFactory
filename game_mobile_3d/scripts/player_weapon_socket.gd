extends BoneAttachment3D
## Runtime hold tuning only; authored meshes and marker locations stay intact.
const WEAPONS = [preload("res://assets/weapons/pistol_v4.glb"), preload("res://assets/weapons/m4a1_v4.glb"), preload("res://assets/weapons/shotgun_v4.glb")]
const HOLD_SCALES = [1.20, 1.12, 1.14]
## Socket space: +Y is barrel-forward, +Z is weapon-up (before Y-up undo).
const HOLD_OFFSETS = [Vector3(0, 0.035, 0.065), Vector3(0, 0.015, 0.075), Vector3(0, 0.020, 0.070)]
## A small rear/underside contact on the existing forward support region.
const SUPPORT_OFFSETS = [Vector3.ZERO, Vector3(0, -0.018, 0.025), Vector3(0, -0.015, 0.020)]
## Arm-local contact near the distal/top edge, rather than its volume center.
const MAIN_HAND_CONTACTS = [Vector3(0, 0.610, 0.090), Vector3(0, 0.587, 0.090), Vector3(0, 0.590, 0.090)]
const SUPPORT_HAND_CONTACTS = [Vector3(0, 0.616, 0.100), Vector3(0, 0.617, 0.100), Vector3(0, 0.623, 0.100)]
var instances: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var grips: Array[Vector3] = []
var supports: Array[Vector3] = []
var equipped: int = 0

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
		muzzles.append(instance.find_child("Muzzle_Point", true, false) as Node3D)
	equip(0)

func equip(index: int) -> void:
	equipped = clampi(index, 0, 2)
	for i in instances.size(): instances[i].visible = i == equipped

func muzzle_position() -> Vector3:
	return muzzles[equipped].global_position if muzzles[equipped] else global_position
