extends SceneTree
## Authoring tool: existing GAF map and authored colors only, no MD2 inputs.
func _initialize()->void:call_deferred("run")
static func original_chunk_transform(chunk:Node3D,chunk_size:int)->bool:
	var parts:=str(chunk.name).split("_")
	if parts.size()!=3 or parts[0]!="Terrain" or not parts[1].is_valid_int() or not parts[2].is_valid_int():return false
	var origin:=Vector3(int(parts[1])*chunk_size,0,int(parts[2])*chunk_size)
	return chunk.global_transform.is_equal_approx(Transform3D(Basis.IDENTITY,origin))
func digest(source:BaseMaterial3D,m:ShaderMaterial)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256)
	h.update(var_to_bytes([source.albedo_color,source.vertex_color_use_as_albedo]))
	h.update(var_to_bytes([m.get_shader_parameter("ground_grade"),m.get_shader_parameter("texture_contrast")]))
	if source.albedo_texture!=null:
		var im:=source.albedo_texture.get_image();if im.is_compressed():im.decompress()
		im.convert(Image.FORMAT_RGBA8);h.update(im.get_data())
	return h.finish().hex_encode()
func mean_color(source:BaseMaterial3D,grade:int,contrast:float)->Vector3:
	var im:Image=source.albedo_texture.get_image() if source.albedo_texture!=null else Image.create(1,1,false,Image.FORMAT_RGBA8)
	if source.albedo_texture==null:im.fill(Color.WHITE)
	if im.is_compressed():im.decompress()
	var mean:=Vector3.ZERO;var tint:=source.albedo_color.srgb_to_linear()
	for y in im.get_height():
		for x in im.get_width():
			var c:=im.get_pixel(x,y).srgb_to_linear()*tint;var v:=Vector3(c.r,c.g,c.b)
			var center:=Vector3(.24,.15,.065);var target:=Vector3(.285,.180,.075)
			if grade==1 and c.g>c.r*1.13 and c.g>c.b*1.35:center=Vector3(.0856,.2168,.0342);target=Vector3(.107,.235,.070)
			elif grade==3:center=Vector3(.24,.27,.27);target=Vector3(.180,.230,.245)
			mean+=(target+(v-center)*contrast).max(Vector3.ZERO)
	return mean/float(im.get_width()*im.get_height())
func run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1 or DirAccess.dir_exists_absolute(args[0]):quit(2);return
	var out:=args[0];DirAccess.make_dir_recursive_absolute(out)
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	w.set_grove_visible(false,w.player.global_position)
	var rows=[];var data:=PackedFloat32Array();var count:=0;var colors={};var fingerprints={}
	for row in w.look.terrain_materials:
		var source:BaseMaterial3D=row[2];var name:String=source.resource_name
		var grade:int=row[3].get_shader_parameter("ground_grade")
		fingerprints[name]=digest(source,row[3])
		colors[name]=mean_color(source,grade,float(row[3].get_shader_parameter("texture_contrast")))
	for chunk:MeshInstance3D in w.geometry.terrain_chunks:
		if not original_chunk_transform(chunk,w.geometry.CHUNK_SIZE):
			push_error("Baker requires the original world-grid transform");w.free();quit(2);return
		for s in chunk.mesh.get_surface_count():
			var arrays:Array=chunk.mesh.surface_get_arrays(s)
			var p:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var stripped:=arrays.duplicate();stripped[Mesh.ARRAY_CUSTOM0]=null;stripped[Mesh.ARRAY_CUSTOM1]=null;stripped[Mesh.ARRAY_CUSTOM2]=null
			var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(stripped))
			var t:=chunk.global_transform
			var world_transform=[t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]
			rows.append({"chunk":str(chunk.name),"surface":s,"count":p.size(),"start":count,"signature":h.finish().hex_encode(),"world_transform":world_transform})
			for i in p.size():
				var point:Vector3=chunk.global_transform*p[i];var normal:Vector3=chunk.global_basis*n[i]
				data.append_array(PackedFloat32Array([point.x,point.y,point.z,normal.x,normal.y,normal.z]));count+=1
	var occupied=[];var side=[];var top=[]
	for cell:Vector3i in w.geometry.cells:
		var entry:Dictionary=w.runtime.palette[w.geometry.cells[cell]]
		if entry.category!="terrain":continue
		var kind:String=entry.kind;var a:Vector3;var b:Vector3
		if kind.begins_with("grass"):a=colors["DI_V3_grass_side"];b=colors["DI_V3_grass_top_0"]
		elif kind.begins_with("dirt"):a=colors["DI_V3_dirt"];b=a
		else:a=colors["DI_V3_stone"];b=a
		for half in roundi(float(entry.height)*2.):
			occupied.append([cell.x,cell.y*2+roundi(float(entry.base_y_offset)*2.)+half,cell.z]);side.append([a.x,a.y,a.z]);top.append([b.x,b.y,b.z])
	var sun:DirectionalLight3D=w.get_node("Sun");var dir:=sun.global_basis.z.normalized()
	var mean:Vector3=w.ambient._material.get_shader_parameter("center")
	var env:Environment=w.get_node("WorldEnvironment").environment
	var meta={"rows":rows,"count":count,"occupied":occupied,"side_colors":side,"top_colors":top,"offset":w.runtime.offset,"source_runtime_sha256":FileAccess.get_sha256(w.DATA),"material_fingerprints":fingerprints,"surface_recipe_sha256":FileAccess.get_sha256("res://materials/world_map_surface_v5.gdshaderinc"),"sun_direction":[dir.x,dir.y,dir.z],"sky_mean":[mean.x,mean.y,mean.z],"ambient_srgb":[env.ambient_light_color.r,env.ambient_light_color.g,env.ambient_light_color.b],"ambient_energy":env.ambient_light_energy,"scope":"Original GAF generated terrain, solid grid and face-average authored albedo"}
	meta["ambient_recipe_identity"]=FileAccess.get_sha256("res://scripts/world_map_ambient.gd")+":"+FileAccess.get_sha256("res://materials/world_map_ambient.gdshader")
	FileAccess.open(out.path_join("vertices.bin"),FileAccess.WRITE).store_buffer(data.to_byte_array())
	FileAccess.open(out.path_join("metadata.json"),FileAccess.WRITE).store_string(JSON.stringify(meta))
	print("TERRAIN_TRANSPORT_EXPORT vertices=",count," rows=",rows.size()," cells=",occupied.size());w.free();quit()
