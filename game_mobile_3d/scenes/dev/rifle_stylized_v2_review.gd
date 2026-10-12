extends "res://scenes/dev/expressive_directional_review.gd"
## Isolated model substitution; inherited animations, physics and production stay intact.
const RIFLE_V2=preload("res://assets/weapons/rifle_stylized_v2_test/Rifle_Stylized_V2.glb")
var original_rifle: Node3D
var candidate_rifle: Node3D
var original_hand: Transform3D
var original_back: Transform3D
var use_v2:=true
var show_back:=false

func _ready() -> void:
	super._ready()
	var s=actor.visual.socket
	original_rifle=s.instances[1]
	original_hand=s.hand_transforms[1];original_back=s.r13_stow_mounts[1]
	candidate_rifle=RIFLE_V2.instantiate();s.add_child(candidate_rifle)
	for mesh: MeshInstance3D in candidate_rifle.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	select_rifle(true)
	gameplay_camera=false;camera.size=5.3
	review_title="RIFLE STYLIZED V2 · ALIGNMENT TEST"

func proportion_preserving(mount: Transform3D) -> Transform3D:
	# Existing mount narrows X to .8925 versus1.05 on Y/Z. Keep its orientation
	# and grip origin, with uniform1.05 scale; marker X coordinates are zero.
	return Transform3D(mount.basis.orthonormalized().scaled(Vector3.ONE*1.05),mount.origin)

func select_rifle(candidate: bool) -> void:
	use_v2=candidate
	var v=actor.visual;var s=v.socket
	original_rifle.hide();candidate_rifle.hide()
	s.instances[1]=candidate_rifle if use_v2 else original_rifle
	s.hand_transforms[1]=proportion_preserving(original_hand) if use_v2 else original_hand
	s.r13_stow_mounts[1]=proportion_preserving(original_back) if use_v2 else original_back
	var model: Node3D=s.instances[1]
	s.grips[1]=s.hand_transforms[1]*model.to_local(model.find_child("*Grip_Point*",true,false).global_position)
	s.supports[1]=s.hand_transforms[1]*model.to_local(model.find_child("*Support_Hand_Point*",true,false).global_position)
	s.muzzles[1]=model.find_child("*Muzzle_Point*",true,false)
	actor.set_review_weapon(true);_armed=true
	if show_back:display_back(true)

func display_back(enabled: bool) -> void:
	show_back=enabled
	actor.set_review_weapon(not enabled);_armed=not enabled
	var s=actor.visual.socket
	s.attach_equipped(&"back" if enabled else &"hand")
	s.instances[1].show()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.physical_keycode==KEY_B:select_rifle(not use_v2);return
		if event.physical_keycode==KEY_H:display_back(not show_back);return
		if event.physical_keycode==KEY_E and show_back:display_back(false);return
	super._unhandled_key_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if original_rifle==null:return
	status.text="RIFLE V2 ALIGNMENT · %s\nB: V2 / preserved R13 · H: back / ready\nWASD move · Shift run · Space jump · L fall\n1 front · 2 three-quarter · 3 side · C gameplay\nProportions preserved · native expressive layers\nBack preview: existing R13 Chest mount\n%s"%["V2 preferred reference" if use_v2 else "Original R13 comparison","Static back fit; holster/draw choreography not certified" if show_back else "Ready grip/support · integration remains Pending"]

