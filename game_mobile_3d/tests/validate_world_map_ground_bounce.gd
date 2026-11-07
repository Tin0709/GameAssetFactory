extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures.append(message)
func frames()->void:
    for i in 3:await process_frame
func finish()->void:
    print("GROUND_BOUNCE checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func run()->void:
    var w:Node3D=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
    check(w.look.has_method("set_ground_bounce"),"Existing main map exposes original reflected-ground lighting")
    if not w.look.has_method("set_ground_bounce"):w.free();finish();return
    var native:bool=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
    check(w.look.ground_bounce_active()==native,"Only supported Day renderer starts with reflected ground")
    var previous_shadow:bool=w.look.directional_shadow_review_active()
    var e:=InputEventKey.new();e.pressed=true;e.physical_keycode=KEY_F1;e.shift_pressed=true
    w._unhandled_input(e)
    check(not w.look.ground_bounce_active() and w.look.directional_shadow_review_active()==previous_shadow,"Shift F1 disables bounce without altering shadow filter")
    w._unhandled_input(e)
    check(w.look.ground_bounce_active()==native,"Shift F1 restores chosen bounce")
    w.look.set_stage(0);await frames();check(not w.look.ground_bounce_active(),"Original B stage suspends bounce")
    w.look.set_stage(2);await frames();check(w.look.ground_bounce_active()==native,"Returning to Day resumes bounce")
    if native:
        var stone:ShaderMaterial
        for item:Array in w.look.terrain_materials:
            if int(item[3].get_shader_parameter("ground_grade"))==3:stone=item[3];break
        check(stone!=null,"Existing mineral material is test receiver")
        var cutaway:ShaderMaterial=w.geometry._make_cutaway_material(stone)
        for parameter:String in ["ground_bounce_map","ground_bounce_direction","ground_bounce_radius"]:
            check(cutaway.get_shader_parameter(parameter)==stone.get_shader_parameter(parameter),"Cutaway retains reflected-ground "+parameter)
        var sun:DirectionalLight3D=w.get_node("Sun");var rotation:Vector3=sun.rotation
        sun.rotation.y+=.2;await frames();check(not w.look.ground_bounce_active(),"Different source direction rejects stale bake")
        sun.rotation=rotation;await frames();check(w.look.ground_bounce_active(),"Original source direction restores cached bake")
        w.look.set_direct_clouds(false);await frames();check(not w.look.ground_bounce_active(),"Legacy color-cloud mode keeps its baseline")
        w.look.set_direct_clouds(true);await frames();check(w.look.ground_bounce_active(),"Direct-light mode restores bounce")
        w.look.toggle_day_finish();await frames();check(not w.look.ground_bounce_active(),"F8 prior finish remains a true source baseline")
        w.look.toggle_day_finish();await frames();check(w.look.ground_bounce_active(),"F8 current finish restores source context")
        check(w.geometry.cells.size()==42996 and w.geometry.terrain_triangles==67694,"Source terrain topology retained")
    w.free();finish()
