# Original generated GAF source only; no game-reference data.
extends SceneTree
var output:String
func _initialize()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:push_error("Supply NEW original-GAF export folder after --");quit(2);return
    output=args[0]
    if output.is_empty() or DirAccess.dir_exists_absolute(output):quit(2);return
    DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func run()->void:
    if RenderingServer.get_current_rendering_method()!="mobile" or RenderingServer.get_rendering_device()==null:push_error("Authoring requires native Mobile Day context");quit(2);return
    var w:Node3D=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
    var rows:Array=[];var points:=PackedFloat32Array();var count:=0
    for chunk:MeshInstance3D in w.geometry.terrain_chunks:
        for s in chunk.mesh.get_surface_count():
            var arrays:Array=chunk.mesh.surface_get_arrays(s)
            var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
            var material:Material=chunk.mesh.surface_get_material(s)
            var mineral:bool=material is ShaderMaterial and int(material.get_shader_parameter("ground_grade"))==3
            if not mineral:continue
            var bytes:PackedByteArray=vertices.to_byte_array();bytes.append_array(normals.to_byte_array());bytes.append_array(arrays[Mesh.ARRAY_INDEX].to_byte_array())
            var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes)
            rows.append({"chunk":str(chunk.name),"surface":s,"count":vertices.size(),"start":count,"signature":h.finish().hex_encode(),"indices":Array(arrays[Mesh.ARRAY_INDEX])})
            for i in vertices.size():
                var p:Vector3=chunk.global_transform*vertices[i];var n:Vector3=chunk.global_basis*normals[i]
                points.append_array(PackedFloat32Array([p.x,p.y,p.z,n.x,n.y,n.z]));count+=1
    var occupancy:Array=[]
    for key:Vector3i in w.geometry._occupied_halves:occupancy.append([key.x,key.y,key.z])
    FileAccess.open(output.path_join("vertices.private.bin"),FileAccess.WRITE).store_buffer(points.to_byte_array())
    var meta:Dictionary={"rows":rows,"count":count,"occupied":occupancy,"ambient_srgb":[w.ambient._color.r,w.ambient._color.g,w.ambient._color.b],"offset":w.runtime.offset,"source_runtime_sha256":FileAccess.get_sha256(w.DATA),"scope":"Original generated GAF mineral surfaces and exact solid half cells"}
    FileAccess.open(output.path_join("metadata.private.json"),FileAccess.WRITE).store_string(JSON.stringify(meta));print("TERRAIN_SKY_EXPORT vertices=",count," rows=",rows.size()," occupied=",occupancy.size());quit()
