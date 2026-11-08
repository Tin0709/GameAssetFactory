extends Node
## Original static upper-sky accessibility of generated GAF mineral faces.
## This is not native MD2 GI. No runtime rays, source mesh edits or extra draws.
const CACHE=preload("res://assets/graphics/world_map_terrain_sky_v001/visibility.res")
var level:Node3D
var enabled:=true
var stream_vertices:=0
var validation_errors:Array[String]=[]
var source_signatures:Dictionary={}
var _installed:=false
var _applied:=false

static func authored_signature(mesh:ArrayMesh,surface:int)->String:
    var arrays:Array=mesh.surface_get_arrays(surface)
    # Additional streams are owned by the new validated transport installer;
    # neither is part of the original GLB. That installer rejects pre-owned data.
    for slot in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2]:arrays[slot]=null
    var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
    context.update(var_to_bytes(arrays));return context.finish().hex_encode()

static func geometry_signature(mesh:ArrayMesh,surface:int)->String:
    var arrays:Array=mesh.surface_get_arrays(surface)
    var bytes:PackedByteArray=arrays[Mesh.ARRAY_VERTEX].to_byte_array()
    bytes.append_array(arrays[Mesh.ARRAY_NORMAL].to_byte_array())
    bytes.append_array(arrays[Mesh.ARRAY_INDEX].to_byte_array())
    var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
    return context.finish().hex_encode()

func setup(world:Node3D)->void:
    level=world;process_priority=10
    if RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null:
        _installed=_install()
    refresh()

func _install(cache:Resource=CACHE)->bool:
    if cache.get_meta("source_runtime_sha256","")!=FileAccess.get_sha256(level.DATA):
        validation_errors.append("Source map changed; retain original terrain lighting");return false
    var values:PackedFloat32Array=cache.get_meta("values",PackedFloat32Array())
    var records:Array=cache.get_meta("rows",[])
    var chunks:Dictionary={}
    for chunk:MeshInstance3D in level.geometry.terrain_chunks:chunks[str(chunk.name)]=chunk
    var expected:Dictionary={}
    for name:String in chunks:
        var mesh:ArrayMesh=chunks[name].mesh
        for s in mesh.get_surface_count():
            var material:Material=mesh.surface_get_material(s)
            if material is ShaderMaterial and int(material.get_shader_parameter("ground_grade"))==3:
                expected[name+":"+str(s)]=true
    if records.size()!=expected.size():validation_errors.append("Incomplete mineral surface coverage");return false
    var rows:Dictionary={};var count:=0
    # Validate the entire cache before replacing any generated mesh.
    for record:Dictionary in records:
        var chunk:MeshInstance3D=chunks.get(str(record.chunk))
        var surface:=int(record.surface);var key:=str(record.chunk)+":"+str(surface)
        if not expected.has(key):validation_errors.append("Unexpected mineral surface coverage "+key);return false
        if chunk==null or surface<0 or surface>=chunk.mesh.get_surface_count() or rows.has(key):
            validation_errors.append("Invalid source row "+key);return false
        var arrays:Array=chunk.mesh.surface_get_arrays(surface)
        if arrays[Mesh.ARRAY_CUSTOM0]!=null or int(record.count)!=arrays[Mesh.ARRAY_VERTEX].size() or int(record.start)!=count \
            or geometry_signature(chunk.mesh,surface)!=str(record.signature):
            validation_errors.append("Generated source geometry changed "+key);return false
        rows[key]=record;count+=int(record.count)
    if count==0 or count!=values.size():validation_errors.append("Incomplete cache");return false
    for value:float in values:
        if not is_finite(value) or value<0. or value>1.:validation_errors.append("Invalid visibility");return false
    var candidates:Dictionary={};var replacements:Dictionary={}
    for name:String in chunks:
        var chunk:MeshInstance3D=chunks[name]
        var original:ArrayMesh=chunk.mesh;var relevant:=false
        for s in original.get_surface_count():
            if rows.has(name+":"+str(s)):relevant=true;break
        if not relevant:continue
        var replacement:=ArrayMesh.new();var signatures:Array[String]=[]
        for s in original.get_surface_count():
            signatures.append(authored_signature(original,s))
            var arrays:Array=original.surface_get_arrays(s);var flags:int=original.surface_get_format(s)
            var key:=name+":"+str(s)
            if rows.has(key):
                var row:Dictionary=rows[key]
                arrays[Mesh.ARRAY_CUSTOM0]=values.slice(int(row.start),int(row.start)+int(row.count))
                flags|=Mesh.ARRAY_FORMAT_CUSTOM0 | (Mesh.ARRAY_CUSTOM_R_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
            replacement.add_surface_from_arrays(original.surface_get_primitive_type(s),arrays,[],{},flags)
            if replacement.get_surface_count()!=s+1:validation_errors.append("Custom stream creation failed");return false
            replacement.surface_set_material(s,original.surface_get_material(s))
        source_signatures[name]=signatures;candidates[name]=replacement;replacements[original]=replacement
    for name:String in candidates:
        var chunk:MeshInstance3D=chunks[name]
        chunk.mesh=candidates[name]
        chunk.get_node("NativeShadowCaster").mesh=chunk.mesh
    # Look owns stage/B material changes through these mesh references. Rebind
    # them atomically with the visuals; do not retain detached old GPU meshes.
    for row:Array in level.look.terrain_materials:
        if replacements.has(row[0]):row[0]=replacements[row[0]]
    stream_vertices=count;return true

func available()->bool:
    if level.get("showcase")!=null and level.showcase.private_primary and not level.showcase.is_day_anchor():return false
    if not _installed or not is_instance_valid(level) or level.ambient==null or not level.ambient.is_active():return false
    if not level.look.local_exposure_available() or ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"):return false
    var environment:Environment=level.get_node("WorldEnvironment").environment
    var source:Color=CACHE.get_meta("ambient_srgb",Color(-1,-1,-1))
    return environment.ambient_light_color.is_equal_approx(source) and level.look.stage==2 \
        and level.look.day_finish_active() and level.look.day_composition_active()

func is_active()->bool:return _applied

func set_enabled(value:bool)->void:
    if value and level.showcase.forest_active():level.showcase.set_atmosphere_review("previous")
    enabled=value;refresh()

func refresh()->void:
    var next:=enabled and available()
    if next==_applied:return
    _applied=next;level.look.set_terrain_sky(next)

func _process(_delta:float)->void:refresh()
