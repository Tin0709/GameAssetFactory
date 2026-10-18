extends "res://scenes/dev/actions_stuff_research/render_pose_presenter.gd"
## Keep the approved rifle on the SAME interpolated render pose as the hands.
var weapon_meshes: Array[MeshInstance3D]=[]
var weapon_locals: Array[Transform3D]=[]
func setup(body: CharacterBody3D,source_visual: Node) -> void:
 for instance: MeshInstance3D in source_visual.rifle_model.find_children("*","MeshInstance3D",true,false):
  weapon_meshes.append(instance);weapon_locals.append(source_visual.rifle_model.global_transform.affine_inverse()*instance.global_transform)
 super.setup(body,source_visual)
func capture() -> void:
 super.capture();current["rifle_support"]=visual.rifle_support_anchor;current["rifle_move_weight"]=visual.rifle_move_weight
 if not previous.has("rifle_support"):previous["rifle_support"]=visual.rifle_support_anchor
 if not previous.has("rifle_move_weight"):previous["rifle_move_weight"]=visual.rifle_move_weight
func prepare(alpha: float) -> void:
 super.prepare(alpha)
 if display_world.is_empty() or visual==null:return
 # Physics endpoints already contain the final constrained pose, including
 # inherited jump scale/shear. Re-solving them would change an authoritative
 # endpoint. Only intermediate render poses need contact reconciliation.
 if render_alpha<=0. or render_alpha>=1.:return
 var carrier: Transform3D=display_world[visual.arm_right]*visual.carrier_in_right_arm
 display_world[visual.carrier_bone]=carrier;display_world[visual.socket_bone]=carrier
 var anchor:=Vector3(previous.rifle_support).lerp(current.rifle_support,render_alpha)
 var chest_world: Transform3D=display_world[visual.chest]
 var left: Transform3D=visual.constrained_left_pose(chest_world.affine_inverse()*Transform3D(display_world[visual.arm_left]),chest_world.affine_inverse()*(carrier*anchor),lerpf(previous.rifle_move_weight,current.rifle_move_weight,render_alpha))
 display_world[visual.arm_left]=chest_world*left
 display_world[visual.forearm_left]=Transform3D(display_world[visual.arm_left])*visual.forearm_left_rest
func _upload() -> void:
 super._upload()
 if display_world.is_empty():return
 var model: Transform3D=Transform3D(display_world[visual.carrier_bone])*visual.socket.hand_transforms[1]
 for i in weapon_meshes.size():RenderingServer.instance_set_transform(weapon_meshes[i].get_instance(),model*weapon_locals[i])
