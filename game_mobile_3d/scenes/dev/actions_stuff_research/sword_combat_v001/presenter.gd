extends "res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_presenter.gd"
var sword_meshes:Array[MeshInstance3D]=[]
var sword_locals:Array[Transform3D]=[]
var display_sword:=Transform3D.IDENTITY
func capture()->void:
	super.capture();current["sword_attachment"]=visual.sword_current_attachment
	if not previous.has("sword_attachment"):previous["sword_attachment"]=visual.sword_current_attachment
func setup(body:CharacterBody3D,source_visual:Node)->void:
	for instance:MeshInstance3D in source_visual.sword_model.find_children("*","MeshInstance3D",true,false):
		sword_meshes.append(instance);sword_locals.append(source_visual.sword_model.global_transform.affine_inverse()*instance.global_transform)
	super.setup(body,source_visual)
func prepare(alpha:float)->void:
	super.prepare(alpha)
	if display_world.is_empty():return
	var attachment:=Transform3D(previous.sword_attachment).interpolate_with(current.sword_attachment,render_alpha)
	display_sword=Transform3D(display_world[visual.arm_right])*attachment*visual.sword_mount
func _upload()->void:
	super._upload()
	if display_world.is_empty() or not visual.sword_equipped:return
	for i in sword_meshes.size():RenderingServer.instance_set_transform(sword_meshes[i].get_instance(),display_sword*sword_locals[i])
