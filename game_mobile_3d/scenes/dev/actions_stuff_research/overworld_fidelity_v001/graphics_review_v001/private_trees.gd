extends Node3D
## Editor-only transient source instances. No imported assets or source arrays in res://.
const Solid=preload("foundation_solid.gdshader")
var materials:Array[ShaderMaterial]=[]
var canopy_bounds:Array[AABB]=[]
var loaded:=0
var grass_roots:=0
var patches_enabled:=true
var patch_roots:Array[Vector2]=[]
var meadow:Node3D
var trunk_bodies:Array[StaticBody3D]=[]
var errors:Array[String]=[]
func setup(lab:Node,rows:Array,hue:float=0.)->void:
	if not OS.has_feature("editor"):return
	meadow=lab.meadow
	var cache:Dictionary={}
	for row:Dictionary in rows:
		var path:String=row.path
		if not lab.private_bundle.permitted(path)or FileAccess.get_sha256(path)!=row.sha256:errors.append("Missing/changed tree "+path.get_file());continue
		if not cache.has(path):
			var document:=GLTFDocument.new();var state:=GLTFState.new()
			var status:=document.append_from_file(path,state)
			if status!=OK:errors.append("Tree GLTF error "+str(status));continue
			var source:Node=document.generate_scene(state);cache[path]=source
		var tree:Node3D=cache[path].duplicate();tree.name="PrivateMD2Tree_"+str(loaded);add_child(tree)
		var p:Array=row.position;tree.position=Vector3(p[0],p[1],p[2]);tree.rotation.y=float(row.yaw)
		for child:Node in tree.find_children("*","MeshInstance3D",true,false):
			var instance:MeshInstance3D=child;var bounds:AABB=instance.global_transform*instance.mesh.get_aabb();canopy_bounds.append(bounds)
			for surface in instance.mesh.get_surface_count():
				var original:BaseMaterial3D=instance.get_active_material(surface)
				var atlas:Texture2D=original.albedo_texture if original!=null else null
				if row.has("texture_path"):
					var image_path:String=row.texture_path
					if not lab.private_bundle.permitted(image_path)or FileAccess.get_sha256(image_path)!=row.texture_sha256:errors.append("Tree atlas changed");continue
					atlas=ImageTexture.create_from_image(Image.load_from_file(image_path))
				if atlas==null:errors.append("Missing tree atlas");continue
				var material:=ShaderMaterial.new();material.shader=Solid;material.set_shader_parameter("atlas",atlas);material.set_shader_parameter("review_alpha_mask",true);material.set_shader_parameter("review_leaf_hue",hue)
				material.set_shader_parameter("gaf_field_origin",Vector2(-52,-52));material.set_shader_parameter("gaf_field_extent",104.);material.set_shader_parameter("gaf_fill_up_ratio",1.)
				instance.set_surface_override_material(surface,material);materials.append(material)
		# Original lightweight trunk collision; source collision metadata not exported.
		var body:=StaticBody3D.new();body.name="TreeTrunkCollisionAdapter";add_child(body);body.position=tree.position+Vector3.UP*1.25
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.38;cylinder.height=2.5;shape.shape=cylinder;body.add_child(shape);trunk_bodies.append(body)
		loaded+=1
	for source:Node in cache.values():source.free()
	_build_grass_patches(lab,rows)
func set_field(texture:Texture2D)->void:
	for material:ShaderMaterial in materials:material.set_shader_parameter("gaf_indirect_field",texture)
func set_phase_scale(scale:float)->void:
	for material:ShaderMaterial in materials:material.set_shader_parameter("review_irradiance_scale",scale)
func set_sky_delta(delta:Vector3)->void:
	for material:ShaderMaterial in materials:material.set_shader_parameter("gaf_sky_delta",delta)

func set_enabled(value:bool)->void:
	visible=value
	if patches_enabled!=value:
		for point:Vector2 in patch_roots:
			var cell:=Vector2i(floori(point.x),floori(point.y))
			if value:
				if not meadow._plant_cells.has(cell):meadow._plant_cells[cell]=[]
				meadow._plant_cells[cell].append(point)
			elif meadow._plant_cells.has(cell):
				meadow._plant_cells[cell].erase(point)
				if meadow._plant_cells[cell].is_empty():meadow._plant_cells.erase(cell)
		patches_enabled=value
	for body:StaticBody3D in trunk_bodies:body.collision_layer=1 if value else 0
func _build_grass_patches(lab:Node,rows:Array)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=291026
	var batches:Dictionary={}
	var assets:=["MD2 | SM_GrassTall_01","MD2 | SM_GrassMedium_02","MD2 | SM_GrassMedium_03"]
	for row:Dictionary in rows:
		var p:Array=row.position;var center:=Vector3(p[0],p[1],p[2])
		for i in 24:
			var heading:=rng.randf()*TAU;var radius:=rng.randf_range(2.7,4.4)
			var point:=center+Vector3(cos(heading)*radius,0,sin(heading)*radius)
			if absf(point.x-lab.meadow.path_center(point.z))<1.2:continue
			var name:String=assets[i%assets.size()]
			if not lab.private_bundle.meshes.has(name):continue
			if not batches.has(name):batches[name]=[]
			batches[name].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),point));grass_roots+=1
			var cell:=Vector2i(floori(point.x),floori(point.z))
			if not lab.meadow._plant_cells.has(cell):lab.meadow._plant_cells[cell]=[]
			lab.meadow._plant_cells[cell].append(Vector2(point.x,point.z));patch_roots.append(Vector2(point.x,point.z))
	for name:String in batches:
		var transforms:Array=batches[name];var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=lab.private_bundle.meshes[name];mm.instance_count=transforms.size()
		for i in transforms.size():mm.set_instance_transform(i,transforms[i]);mm.set_instance_custom_data(i,Color(rng.randf()*TAU,0,0,1))
		var instance:=MultiMeshInstance3D.new();instance.multimesh=mm;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;instance.extra_cull_margin=1.8;add_child(instance)
