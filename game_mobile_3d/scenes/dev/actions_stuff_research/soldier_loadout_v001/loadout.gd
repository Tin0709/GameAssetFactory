extends RefCounted
## Appearance-only research adapter. Existing rig, pose writer and sockets survive.
const SKIN=preload("res://scenes/dev/actions_stuff_research/soldier_loadout_v001/Soldier_Skin_v001.glb")
const RIFLE=preload("res://scenes/dev/actions_stuff_research/soldier_loadout_v001/Rifle_Sand_Block_V1.glb")
static func install_skin(visual: Node) -> void:
 var source:=SKIN.instantiate()
 var imported: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
 var mesh:=MeshInstance3D.new();mesh.name="SoldierSkinV001";mesh.mesh=imported.mesh
 # Map names onto the approved runtime rig, retaining the source inverse binds.
 # Slim arms then rotate about their actual centres and meet the original grip;
 # the authored shirt/sleeves cover the small runtime shoulder-spacing difference.
 var skin:=Skin.new();skin.set_bind_count(imported.skin.get_bind_count())
 for i in skin.get_bind_count():
  var name: StringName=imported.skin.get_bind_name(i)
  var bone: int=visual.skeleton.find_bone(name)
  assert(bone>=0,"Unmapped Soldier skin bone: "+str(name))
  skin.set_bind_name(i,name);skin.set_bind_pose(i,imported.skin.get_bind_pose(i))
 mesh.skin=skin;visual.skeleton.add_child(mesh);mesh.skeleton=NodePath("..")
 for old: MeshInstance3D in visual.meshes:old.hide()
 visual.meshes.clear();visual.meshes.append(mesh)
 for surface in mesh.mesh.get_surface_count():
  var material: BaseMaterial3D=mesh.mesh.surface_get_material(surface).duplicate()
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;material.roughness=1.
  if material.resource_name.contains("WC_Ragged"):
   material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.5;material.cull_mode=BaseMaterial3D.CULL_DISABLED
  mesh.set_surface_override_material(surface,material)
 source.free()
