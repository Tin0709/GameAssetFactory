extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func ticks(count:int=3)->void:
	for i in count:await process_frame
func click(button:Button)->void:
	var motion:=InputEventMouseMotion.new();motion.position=button.get_global_rect().get_center();motion.global_position=motion.position;root.push_input(motion,true)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.position=button.get_global_rect().get_center();event.global_position=event.position;event.pressed=true;root.push_input(event,true)
	await process_frame
	event=event.duplicate();event.pressed=false;event.button_mask=0;root.push_input(event,true)
	await ticks()
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	check(lab.md2_sabre_prototype_enabled and lab.sword_combat_enabled and lab.sword_private_reference_enabled and lab.performance_test_enabled and lab.grass_field_blocks==100 and lab.camera_size==14.5,"F6 defaults to Sabre while retaining original lab/environment settings")
	root.add_child(lab);current_scene=lab;await ticks()
	check(lab.sabre_mode!=null,"F6-style scene startup needs no CLI flag or hidden mode click")
	if lab.sabre_mode==null:lab.free();quit(1);return
	check(lab.zombie_combat==null and lab.performance_controls==null and lab.sword_combat==null,"Direct F6 entry constructs only the new player/Sabre controller")
	var back:=lab.find_child("ReturnOriginalLabButton",true,false) as Button
	await click(back);lab=current_scene
	check(lab.sabre_mode==null and lab.player.get_script().resource_path.ends_with("sword_combat_v001/actor.gd"),"Default lab retains its original actor")
	var entry:=lab.find_child("PlayerSabrePrototypeButton",true,false) as Button
	check(entry!=null and entry.visible,"Original lab has a visible prototype entry button")
	await click(entry);lab=current_scene
	check(lab.sabre_mode!=null and bool(get_meta("md2_sabre_prototype_selected")),"Real GUI click switches into prototype in same scene")
	if lab.sabre_mode==null:lab.free();quit(1);return
	var actor=lab.player;var before:int=actor.accepted_count
	var review:Button
	for node:Node in lab.sabre_mode.panel.find_children("*","Button",true,false):
		if node.text=="Review selected":review=node
	await click(review)
	check(actor.accepted_count==before and actor.review_clip=="Idle","Review GUI click is consumed and cannot fire a world attack")
	back=lab.find_child("ReturnOriginalLabButton",true,false) as Button
	await click(back);lab=current_scene
	check(lab.sabre_mode==null and not bool(get_meta("md2_sabre_prototype_selected")),"Return GUI click selects original lab")
	lab.free();current_scene=null
	# The explicit false metadata is also stronger than inspector/CLI opt-in.
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;root.add_child(lab)
	check(lab.sabre_mode==null,"Return selection overrides an inspector opt-in")
	lab.free();remove_meta("md2_sabre_prototype_selected")
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
	check(lab.sabre_mode!=null,"A fresh F6 run returns to Sabre after the process-local old-mode selection ends")
	lab.free()
	print("SABRE_MODE_SWITCH ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
