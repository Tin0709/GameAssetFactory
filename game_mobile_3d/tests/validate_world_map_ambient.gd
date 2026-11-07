extends SceneTree
# A missing/stale ambient owner breaks either live scene toggling or restoration.
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func frames() -> void:
    for i in 3: await process_frame
func snapshot(env: Environment) -> Dictionary:
    var result := {}
    for field: String in ["sky", "ambient_light_source", "ambient_light_sky_contribution", "reflected_light_source"]:
        result[field] = env.get(field)
    return result
func finish() -> void:
    print("WORLD_MAP_AMBIENT checks=",checks," failures=",JSON.stringify(failures))
    quit(0 if failures.is_empty() else 1)
func run() -> void:
    var world: Node3D = load("res://scenes/WorldMap.tscn").instantiate()
    root.add_child(world)
    check(world.map_ready, "Existing map builds")
    var fill: Node = world.get_node_or_null("DirectionalAmbient")
    check(fill != null, "Existing main map exposes the reversible directional ambient option")
    if fill == null: world.free();finish();return
    var env: Environment = world.get_node("WorldEnvironment").environment
    var native := RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null
    check(fill.is_active() == native, "Only native Mobile applies the original sky field")
    fill.set_enabled(false)
    var baseline := snapshot(env)
    var color := env.ambient_light_color
    var energy := env.ambient_light_energy
    var background := env.background_color
    var exposure := env.tonemap_exposure
    var sun: Transform3D = world.get_node("Sun").transform
    var event := InputEventKey.new()
    event.physical_keycode = KEY_F11; event.pressed = true
    world._unhandled_input(event)
    check(fill.is_active() == native, "F11 enables supported ambient and retains fallback")
    check(env.ambient_light_color == color and env.ambient_light_energy == energy, "Palette remains the ambient input, not overwritten output")
    check(env.background_color == background and env.tonemap_exposure == exposure and world.get_node("Sun").transform == sun, "Background, exposure and sun are preserved")
    world._unhandled_input(event)
    check(snapshot(env) == baseline, "F11 restores every owned Environment field")
    if native:
        fill.set_enabled(true)
        var first_sky: Sky = env.sky
        world.look.set_day_palette(true, false)
        await frames()
        var first_center: Vector3 = first_sky.sky_material.get_shader_parameter("center")
        world.look.set_day_palette(true, true)
        await frames()
        var second_center: Vector3 = first_sky.sky_material.get_shader_parameter("center")
        check(env.sky == first_sky and first_center.distance_to(second_center) > 0.005, "Palette changes update cached lighting without allocating another Sky")
        world.look.set_stage(0)
        await frames()
        check(not fill.is_active() and snapshot(env) == baseline, "B baseline releases old Environment ownership")
        world.look.set_stage(2)
        await frames()
        check(fill.is_active(), "Returning to reference look reacquires current Environment")
        var prior: Environment = world.get_node("WorldEnvironment").environment
        var replacement := Environment.new()
        replacement.background_mode = Environment.BG_COLOR
        replacement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        replacement.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
        replacement.ambient_light_color = Color(0.3,0.5,0.6)
        replacement.ambient_light_energy = 0.2
        var replacement_before := snapshot(replacement)
        world.get_node("WorldEnvironment").environment = replacement
        await frames()
        check(prior.sky == null and fill.is_active(), "Replacement restores old Environment and lights the new one")
        var foreign := Sky.new()
        replacement.sky = foreign
        await frames()
        check(replacement.sky == foreign and not fill.is_active(), "A foreign sky is preserved rather than overwritten")
        replacement.sky = null
        replacement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        await frames()
        check(fill.is_active(), "Eligible constant-fill Environment can be reacquired")
        var held: Environment = replacement
        world.free()
        check(snapshot(held) == replacement_before, "Exit restores the retained Environment resource")
    else:
        check(snapshot(env) == baseline, "Fallback does not mutate the Environment")
        world.free()
    finish()
