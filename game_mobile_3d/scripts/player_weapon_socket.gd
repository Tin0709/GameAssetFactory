extends BoneAttachment3D
## A single non-deforming authored socket, with unchanged weapon-local markers.
const WEAPONS = [preload("res://assets/weapons/pistol_v4.glb"), preload("res://assets/weapons/m4a1_v4.glb"), preload("res://assets/weapons/shotgun_v4.glb")]
var instances: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var equipped: int = 0

func _ready() -> void:
	bone_name = "WeaponSocket"
	for asset in WEAPONS:
		var instance := asset.instantiate() as Node3D
		# Socket stores a Blender-local frame; standalone GLB vertices/markers
		# are already Y-up. Undo that conversion once at the attachment boundary.
		instance.rotation.x = PI / 2.0
		add_child(instance)
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
