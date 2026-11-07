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
    print("ACTOR_FILL checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func run()->void:
    var w:Node3D=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
    var fill:Node=w.get_node_or_null("ActorSkyVisibility")
    check(fill!=null,"Existing main scene exposes original local actor sky visibility")
    if fill==null:w.free();finish();return
    var native:bool=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
    check(fill.is_active()==native,"Only supported renderer receives actor fill")
    var e:=InputEventKey.new();e.pressed=true;e.physical_keycode=KEY_F11;e.shift_pressed=true
    var ambient:bool=w.ambient.enabled
    w._unhandled_input(e)
    check(not fill.enabled and w.ambient.enabled==ambient,"Shift F11 changes local fill without toggling global sky")
    w._unhandled_input(e)
    check(fill.enabled and w.ambient.enabled==ambient,"Shift F11 restores local fill independently")
    var snapshot:Array=[]
    for item:Array in w.look.actor_materials:snapshot.append(item[0].get_active_material(item[1]))
    w.look.set_stage(0);await frames()
    check(not fill.is_active(),"B suspends local fill")
    for item:Array in w.look.actor_materials:check(item[0].get_surface_override_material(item[1])==item[2],"B restores actual original actor material")
    w.look.set_stage(2);await frames()
    check(fill.is_active()==native,"Reference look resumes selected local fill")
    if native:
        w.player.set_physics_process(false)
        w.player.position=Vector3(-4.6,3.02,-2.55);w.player.reset_physics_interpolation()
        await frames();fill.refresh()
        var under:PackedVector4Array=fill.current_coefficients()
        check(under[0].length()>0.01,"Original oak affects its covered receiver")
        w.player.position.y=9.;w.player.reset_physics_interpolation()
        await frames();fill.refresh()
        check(fill.current_coefficients()[0].length()<0.000001,"Above-crown player is not darkened by a ground-only footprint")
        w.grove.hide();fill.refresh()
        check(fill.current_coefficients()[0].length()<0.000001,"Hidden grove releases actor occlusion")
        w.grove.show();w.reset_player();fill.refresh()
        w.look.set_direct_clouds(false);await frames()
        var lit:ShaderMaterial=w.look.actor_materials[0][0].get_active_material(w.look.actor_materials[0][1])
        check(lit!=null and lit.get_shader_parameter("sky_block")!=null,"Local fill survives F3-off native direct lighting")
    w.free();finish()
