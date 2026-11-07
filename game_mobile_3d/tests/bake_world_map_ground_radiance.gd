# Original GAF-only authoring utility. Output folder is refused if it exists.
extends SceneTree
var output:String
func _initialize()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:push_error("Supply a NEW original-GAF bake directory after --");quit(2);return
    output=args[0]
    if output.is_empty() or DirAccess.dir_exists_absolute(output):quit(2);return
    DirAccess.make_dir_recursive_absolute(output);create_timer(100.).timeout.connect(func():quit(3));call_deferred("run")
func frames(n:int)->void:
    for i in n:await process_frame
    await RenderingServer.frame_post_draw
func run()->void:
    if RenderingServer.get_current_rendering_method()!="mobile" or RenderingServer.get_rendering_device()==null:push_error("Bake requires native Mobile pixel shading");quit(2);return
    root.size=Vector2i(64,64);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var vp:=SubViewport.new();vp.size=Vector2i(20,20);vp.own_world_3d=true;vp.use_hdr_2d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
    var w:Node3D=load("res://scenes/WorldMap.tscn").instantiate();vp.add_child(w)
    w.set_process(false);w.set_physics_process(false);w.player.set_physics_process(false);w.player.visual.set_process(false)
    w.look.set_ground_bounce(false) # Prevent feedback from a previous bake.
    w.actor_fill.set_enabled(false);w.ambient.set_enabled(false);w.get_node("Actors").hide();w.get_node("HUD").hide();w.look.freeze_motion(1.38)
    w.geometry.update_cutaway(Vector3.ZERO,Vector3.ZERO,false)
    for batch:MultiMeshInstance3D in w.geometry.vegetation_batches+w.geometry.accent_batches:
        if batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:batch.hide()
        else:batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    for visual:MeshInstance3D in w.grove.find_children("*","MeshInstance3D",true,false):
        if visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:visual.hide()
    var variants:Dictionary={}
    var visited:Dictionary={}
    for item:Array in w.look.terrain_materials:
        var material:ShaderMaterial=item[3]
        if visited.has(material):continue
        visited[material]=true
        var original:Shader=material.shader
        if not variants.has(original):
            var shader:=Shader.new();shader.code=original.code.replace("shader_type spatial;","shader_type spatial;\n#define GAF_WORLD_FORCE_LAMBERT");variants[original]=shader
        material.shader=variants[original];material.set_shader_parameter("clouds_enabled",false)
    var env:Environment=w.get_node("WorldEnvironment").environment
    env.sky=null;env.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
    env.fog_enabled=false;env.glow_enabled=false;env.adjustment_enabled=false;env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.
    var sun:DirectionalLight3D=w.get_node("Sun");sun.light_energy=1.;sun.light_color=Color.WHITE;sun.light_specular=0.;sun.directional_shadow_max_distance=60.
    var direction:Vector3=sun.global_basis.z.normalized()
    var camera:Camera3D=w.get_node("Camera3D");camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.rotation_degrees=Vector3(-90,0,0);camera.size=10.;camera.near=.05;camera.far=80.
    vp.msaa_3d=Viewport.MSAA_DISABLED;vp.scaling_3d_scale=1.
    var origin:Vector2=w.look.path_map_origin;var extent:Vector2=w.look.path_map_size
    var dimensions:=Vector2i(extent*2.)
    var image:=Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBAF)
    var roof:=0.0
    for y in int(extent.y):
        for x in int(extent.x):roof=maxf(roof,w.look.path_map_image.get_pixel(x,y).g)
    for z in ceili(extent.y/10.):
        for x in ceili(extent.x/10.):
            camera.position=Vector3(origin.x+x*10.+5.,roof+6.,origin.y+z*10.+5.)
            await frames(4)
            var tile:=vp.get_texture().get_image();tile.convert(Image.FORMAT_RGBAF)
            image.blit_rect(tile,Rect2i(0,0,20,20),Vector2i(x*20,z*20))
    FileAccess.open(output.path_join("radiance_rgba32.private.bin"),FileAccess.WRITE).store_buffer(image.get_data())
    image.convert(Image.FORMAT_RGBAH);image.save_exr(output.path_join("radiance.private.exr"))
    var metadata:Dictionary={"size":[dimensions.x,dimensions.y],"pixels_per_metre":2.0,"tile_span_metres":10.0,"origin":[origin.x,origin.y],"extent":[extent.x,extent.y],"sun_direction":[direction.x,direction.y,direction.z],"unit_energy":1.,"white_light":true,"ambient":false,"specular":false,"fog_grade":false,"roof":roof,"source_sha256":w.runtime.source_sha256,"source_runtime_sha256":FileAccess.get_sha256(w.DATA),"scope":"Original GAF tiled render. Static source illumination, tile-shadow precision and indirect patch model are approximations, not native MD2 GI."}
    FileAccess.open(output.path_join("metadata.private.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata));print("GROUND_RADIANCE_BAKE ",JSON.stringify(metadata));quit()

