extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures.append(message)
func frames()->void:
    for i in 3:await process_frame
func blocked(values:PackedVector4Array,normal:Vector3)->float:
    var result:=0.0
    for i in values.size()/6:
        var c:=values[i*6+3];var q:=values[i*6+4];var r:=values[i*6+5]
        result=maxf(result,clampf(c.x+Vector3(c.y,c.z,c.w).dot(normal)+Vector3(q.x,q.y,q.z).dot(normal*normal)+2.0*(q.w*normal.x*normal.y+r.x*normal.x*normal.z+r.y*normal.y*normal.z),0,1))
    return result
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
    w.look.set_stage(1);await frames()
    for item:Array in w.look.actor_materials:check(item[0].get_active_material(item[1])==item[3],"Material-only stage retains its native actor adapter")
    w.look.set_stage(2);await frames()
    if native:
        w.player.set_physics_process(false)
        w.player.position=Vector3(-4.6,3.02,-2.55);w.player.reset_physics_interpolation()
        await frames();fill.refresh()
        var under:PackedVector4Array=fill.current_coefficients()
        check(blocked(under,Vector3.UP)>0.01,"Original oak affects its covered receiver")
        var crossing:Array=[]
        for z:float in [4.400636044,4.402636044]:
            w.player.position=Vector3(-29.44,3.02,z);w.player.reset_physics_interpolation()
            await frames();fill.refresh();crossing.append(fill.current_coefficients())
        for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3.UP]:
            check(absf(blocked(crossing[0],normal)-blocked(crossing[1],normal))<.001,"Directional fill stays continuous across candidate rankings "+str(normal))
        w.player.position.y=9.;w.player.reset_physics_interpolation()
        await frames();fill.refresh()
        check(fill.current_coefficients()[0].length()<0.000001,"Above-crown player is not darkened by a ground-only footprint")
        w.grove.hide();fill.refresh()
        check(fill.current_coefficients()[0].length()<0.000001,"Hidden grove releases actor occlusion")
        w.grove.show();w.reset_player();fill.refresh()
        w.look.set_direct_clouds(false);await frames()
        var lit:ShaderMaterial=w.look.actor_materials[0][0].get_active_material(w.look.actor_materials[0][1])
        check(lit!=null and lit.get_shader_parameter("sky_block")!=null,"Local fill survives F3-off native direct lighting")
        w.look.publish_clouds(17.3)
        check(lit.get_shader_parameter("albedo_tint")==w.look.actor_materials[0][3].albedo_color,"F3-off retains existing actor cloud-color fallback")
        w.look.set_direct_clouds(true);await frames()
        check(lit.get_shader_parameter("albedo_tint")==w.look.actor_materials[0][4],"F3 return restores ungraded tint for direct-only cloud shading")
    var saved_grove:Node3D=w.grove
    w.grove=null
    var fallback:Node=load("res://scripts/world_map_actor_fill.gd").new()
    root.add_child(fallback);fallback.setup(w)
    check(not fallback.is_active(),"Optional grove build failure preserves native actor fallback")
    fallback.free();w.grove=saved_grove
    w.free();finish()
