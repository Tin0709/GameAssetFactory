extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var v=scene.player.visual
 check(v.get("rifle_ready_active")==true,"Existing dev scene must activate the approved Rifle Ready set")
 if not failures.is_empty():scene.free();quit(1);return
 check(v.rifle_clips.size()==3,"Exactly three approved Rifle Ready clips")
 check(v.rifle_clips.Idle.clip.resource_name=="Rifle_Ready_Idle_ActionsStyle_v004","Exact approved Idle")
 check(v.rifle_clips.Walk.clip.resource_name=="Rifle_Ready_Walk_ActionsStyle_v001","Exact approved Walk")
 check(v.rifle_clips.Run.clip.resource_name=="Rifle_Ready_Run_ActionsStyle_v001","Exact approved Run")
 check(v.rifle_model.visible,"Actual Rifle Stylized V2 visible")
 print("RIFLE_READY ",JSON.stringify({"failures":failures}));scene.free();quit(0 if failures.is_empty() else 1)
