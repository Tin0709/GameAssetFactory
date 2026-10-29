extends Node3D
## Editor-only transient source instances. No imported assets or source arrays in res://.
const Solid=preload("foundation_solid.gdshader")
var materials:Array[ShaderMaterial]=[]
var canopy_bounds:Array[AABB]=[]
var loaded:=0
var errors:Array[String]=[]
func setup(lab:Node,rows:Array)->void:
	if not OS.has_feature("editor"):return
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
				var material:=ShaderMaterial.new();material.shader=Solid;material.set_shader_parameter("atlas",atlas);material.set_shader_parameter("review_alpha_mask",true)
				material.set_shader_parameter("gaf_field_origin",Vector2(-52,-52));material.set_shader_parameter("gaf_field_extent",104.);material.set_shader_parameter("gaf_fill_up_ratio",1.)
				instance.set_surface_override_material(surface,material);materials.append(material)
		# Original lightweight trunk collision; source collision metadata not exported.
		var body:=StaticBody3D.new();body.name="TreeTrunkCollisionAdapter";add_child(body);body.position=tree.position+Vector3.UP*1.25
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.38;cylinder.height=2.5;shape.shape=cylinder;body.add_child(shape)
		loaded+=1
	for source:Node in cache.values():source.free()
func set_field(texture:Texture2D)->void:
	for material:ShaderMaterial in materials:material.set_shader_parameter("gaf_indirect_field",texture)
func set_sky_delta(delta:Vector3)->void:
	for material:ShaderMaterial in materials:material.set_shader_parameter("gaf_sky_delta",delta)
