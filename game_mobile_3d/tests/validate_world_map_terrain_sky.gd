extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    checks+=1
    if not ok:failures.append(message)
func frames()->void:
    for i in 4:await process_frame
func finish()->void:
    print("TERRAIN_SKY checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func run()->void:
    var w:Node3D=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
    var sky:Node=w.get_node_or_null("TerrainSkyVisibility")
    check(sky!=null,"Main map exposes original terrain sky visibility")
    if sky==null:w.free();finish();return
    var native:bool=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
    check(sky.is_active()==native,"Supported current Day enables static terrain visibility")
    var e:=InputEventKey.new();e.pressed=true;e.physical_keycode=KEY_F12
    var ambient:bool=w.ambient.enabled
    w._unhandled_input(e);await frames()
    check(not sky.is_active() and w.ambient.enabled==ambient,"F12 disables only local terrain visibility")
    w._unhandled_input(e);await frames();check(sky.is_active()==native,"F12 restores selected local visibility")
    w.look.set_stage(0);await frames();check(not sky.is_active(),"Original B look retains original ambient")
    w.look.set_stage(2);await frames();check(sky.is_active()==native,"Current look restores selected local visibility")
    if native:
        check(sky.stream_vertices==50894,"Expected original mineral vertex count")
        check(sky.validation_errors.is_empty(),"All cached source signatures match")
        for chunk:MeshInstance3D in w.geometry.terrain_chunks:
            if not sky.source_signatures.has(str(chunk.name)):continue
            for s in chunk.mesh.get_surface_count():
                check(sky.authored_signature(chunk.mesh,s)==sky.source_signatures[str(chunk.name)][s],"Original mesh attributes retained "+str(chunk.name)+":"+str(s))
            check(chunk.get_node("NativeShadowCaster").mesh==chunk.mesh,"Shadow and visual geometry stay coherent "+str(chunk.name))
        w.ambient.set_enabled(false);await frames();check(not sky.is_active(),"F11 constant-fill fallback is unchanged")
        w.ambient.set_enabled(true);await frames();check(sky.is_active(),"Source directional sky resumes visibility")
        w.look.toggle_day_finish();await frames();check(not sky.is_active(),"Previous F8 finish remains a baseline")
        w.look.toggle_day_finish();await frames();check(sky.is_active(),"Current F8 restores visibility")
    check(w.geometry.cells.size()==42996 and w.geometry.terrain_triangles==67694,"Terrain topology retained")
    w.free();finish()
