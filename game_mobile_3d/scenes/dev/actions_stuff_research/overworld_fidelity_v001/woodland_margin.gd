extends Node3D
## Original render-only scenery outside the meadow's two visible background edges.
const GROUND=preload("woodland_ground.gdshader")
const BANK_VIEW_DISTANCE:=74.
const GROUND_TRIANGLES:=[Vector2i(0,0),Vector2i(2,0),Vector2i(2,2),Vector2i(0,0),Vector2i(2,2),Vector2i(0,2)]

var _banks:Array[MeshInstance3D]=[]
var _overview:=false

func set_overview(value:bool)->void:
	if value==_overview:return
	_overview=value
	for bank in _banks:bank.visibility_range_end=0. if value else BANK_VIEW_DISTANCE

func build(path_center:Callable)->void:
	var roots:=_build_forest()
	_build_border(roots)
	_build_verge(path_center)

func _build_border(roots:Array[Vector3])->void:
	var material:=ShaderMaterial.new()
	material.shader=GROUND
	material.set_shader_parameter("ground_grain",_grain_map())
	var field:=FastNoiseLite.new()
	field.seed=360121
	field.frequency=.17
	var banks:Array[Rect2i]=[]
	for x in range(-74,52,42):banks.append(Rect2i(x,-74,mini(42,52-x),24))
	for z in range(-50,52,34):banks.append(Rect2i(-74,z,24,mini(34,52-z)))
	for area:Rect2i in banks:
		var center:=Vector3(area.position.x+area.size.x*.5,0.,area.position.y+area.size.y*.5)
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		var vertices:Dictionary={}
		var colors:Dictionary={}
		for z in range(area.position.y,area.end.y,2):
			for x in range(area.position.x,area.end.x,2):
				for delta:Vector2i in GROUND_TRIANGLES:
					var point:=Vector2i(x,z)+delta
					if not vertices.has(point):
						var depth:=maxf(-point.x-50.,-point.y-50.)
						var position:=Vector3(point.x,_border_height(Vector2(point)),point.y)
						var shade:=0.
						for tree:Vector3 in roots:
							var offset:=Vector2(tree.x-position.x+.55,tree.z-position.z+1.3)
							shade=maxf(shade,1.-smoothstep(.6,15.,offset.length_squared()))
						var grain:=field.get_noise_2d(point.x,point.y)
						var base:=Color("#59803f").lerp(Color("#4c6338"),smoothstep(0.,14.,depth))
						base=base.lerp(Color("#92995d"),clampf(.15+grain*.31,0.,.39))
						vertices[point]=position-center
						colors[point]=base.darkened(.27*shade).srgb_to_linear()
					tool.set_color(colors[point])
					tool.set_normal(Vector3.UP)
					tool.add_vertex(vertices[point])
		var bank:=MeshInstance3D.new()
		bank.mesh=tool.commit()
		bank.position=center
		# Cap only distant bank tiles that would otherwise survive conservative frustum culling.
		bank.visibility_range_end=BANK_VIEW_DISTANCE
		bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bank)
		_banks.append(bank)

func _border_height(at:Vector2)->float:
	var depth:=maxf(-at.x-50.,-at.y-50.)
	return -.02+smoothstep(1.,17.,depth)*(.4+sin(at.x*.17)*.49+sin(at.y*.29)*.22)

func _build_forest()->Array[Vector3]:
	var roots:Array[Vector3]=[]
	var leaves:=StandardMaterial3D.new()
	leaves.vertex_color_use_as_albedo=true
	leaves.roughness=1.
	leaves.vertex_color_is_srgb=true
	leaves.metallic_specular=0.
	leaves.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pixel:=Image.create_empty(16,16,false,Image.FORMAT_RGB8)
	var rng:=RandomNumberGenerator.new()
	rng.seed=712431
	for y in 16:
		for x in 16:
			var v:=rng.randf_range(.88,1.)
			pixel.set_pixel(x,y,Color(v,v,v))
	leaves.albedo_texture=ImageTexture.create_from_image(pixel)
	var tree_meshes:Array[Mesh]=[]
	for kind in 3:tree_meshes.append(_make_tree(kind,leaves))
	for side in 2:
		for segment in 4:
			var crowns:=SurfaceTool.new()
			crowns.begin(Mesh.PRIMITIVE_TRIANGLES)
			crowns.set_material(leaves)
			var has_crowns:=false
			var along:float=-37.5+25.*segment
			var shifts:Array[Vector2]=[Vector2(-8.,3.2),Vector2(-3.2,6.9),Vector2(.85,2.4),Vector2(5.,8.8),Vector2(9.,3.9)]
			for i in shifts.size():
				var q:=shifts[i]
				var variation:=(segment+i+side)%3
				var distance:float=-(50.+q.y)
				var long:float=along+q.x+rng.randf_range(-.6,.6)
				if side==1 and long<-46.:continue
				var root:=Vector2(distance,long) if side==0 else Vector2(long,distance)
				var p:=Vector3(root.x,_border_height(root),root.y)
				roots.append(p)
				var tree_scale:=rng.randf_range(.89,1.29) if i==1 or i==3 else rng.randf_range(.68,.98)
				var rotation:=Basis(Vector3.UP,rng.randf_range(-.65,.65))
				crowns.append_from(tree_meshes[variation],0,Transform3D(rotation.scaled(Vector3(tree_scale*.91,tree_scale,tree_scale*.91)),p))
				has_crowns=true
			if has_crowns:
				var group:=MeshInstance3D.new()
				group.mesh=crowns.commit()
				group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(group)
	return roots

func _make_tree(kind:int,material:Material)->ArrayMesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var bark:=Color("#796451")
	var leaf:=Color("#729348") if kind==0 else (Color("#648640") if kind==1 else Color("#587b43"))
	_append_box(tool,Vector3(0,.52,0),Vector3(.64,1.04,.64),bark.darkened(.30))
	_append_box(tool,Vector3(0,1.86,0),Vector3(.57,1.7,.57),bark)
	_append_box(tool,Vector3(.36,2.55,-.06),Vector3(.9,.48,.45),bark.darkened(.12))
	_append_box(tool,Vector3(.0,3.15,0),Vector3(2.52,1.37,2.56),leaf.darkened(.14))
	_append_box(tool,Vector3(-.76,3.32,.32),Vector3(1.55,1.19,1.73),leaf)
	_append_box(tool,Vector3(.82,3.8,-.46),Vector3(1.62,1.34,1.57),leaf.darkened(.07))
	_append_box(tool,Vector3(.12,4.03,.53),Vector3(2.08,1.29,1.64),leaf.lightened(.025))
	_append_box(tool,Vector3(-.17,4.52,-.15),Vector3(1.48,1.29,1.49),leaf.lightened(.045))
	if kind==1:
		_append_box(tool,Vector3(-.77,4.95,-.26),Vector3(1.16,.75,1.28),leaf.lightened(.055))
	elif kind==2:
		_append_box(tool,Vector3(.0,4.78,1.04),Vector3(1.12,.95,1.12),leaf.lightened(.055))
		_append_box(tool,Vector3(1.28,3.61,.66),Vector3(.84,1.1,1.25),leaf.darkened(.12))
	for i in 3:
		var heading:=float(i)*2.399963+kind*.51
		var shrub:=Vector3(cos(heading)*.91,.18,sin(heading)*.86)
		_append_box(tool,shrub,Vector3(.52,.34,.50),leaf.darkened(.29))
	for i in 12:
		var heading:=float(i)*2.399963+kind*1.62
		var p:=Vector3(cos(heading)*(1.22+sin(i*.8)*.17),3.55+sin(i*2.21)*.61,sin(heading)*1.27)
		var size:=Vector3(.43+cos(i*.64)*.15,.49+sin(i*1.34)*.15,.46)
		_append_box(tool,p.snapped(Vector3.ONE*.14),size,leaf.lightened(.02*cos(i*1.)))
	tool.index()
	return tool.commit()

func _append_box(tool:SurfaceTool,center:Vector3,size:Vector3,color:Color)->void:
	for normal:Vector3 in [Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var axis:=Vector3.RIGHT if absf(normal.y)>.5 else Vector3.UP
		var cross_axis:=normal.cross(axis)
		for uv:Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
			var p:=center+(normal*.5+(uv.x-.5)*axis+(uv.y-.5)*cross_axis)*size
			tool.set_normal(normal)
			tool.set_uv(uv)
			tool.set_color(color)
			tool.add_vertex(p)


func _grain_map()->ImageTexture:
	var img:=Image.create_empty(64,64,false,Image.FORMAT_RG8)
	var rng:=RandomNumberGenerator.new()
	rng.seed=932654
	for z in 64:
		for x in 64:
			var coarse:=float(((x/4)*983+(z/4)*421)%31)/30.
			img.set_pixel(x,z,Color(rng.randf(),coarse,0.))
	return ImageTexture.create_from_image(img)

func _build_verge(path_center:Callable)->void:
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=1.
	mat.metallic_specular=0.
	var rng:=RandomNumberGenerator.new()
	rng.seed=51023
	var mesh:=_make_tuft(mat)
	for side in 2:
		for segment in 4:
			var transforms:Array[Transform3D]=[]
			for i in 82:
				var along:float=-49.+segment*24.6+rng.randf_range(0.,24.6)
				var depth:=lerpf(.67,8.,pow(rng.randf(),1.75))
				var d:=-(50.+depth)
				var p:=Vector2(d,along) if side==0 else Vector2(along,d)
				if side==1 and absf(along-float(path_center.call(d)))<1.15:continue
				if rng.randf()>.72+.22*sin(along*.41+side):continue
				var k:=rng.randf_range(.65,1.45)
				var basis:=Basis(Vector3.UP,rng.randf_range(0.,TAU)).scaled(Vector3(k,k,k))
				transforms.append(Transform3D(basis,Vector3(p.x,_border_height(p),p.y)))
			if transforms.is_empty():continue
			var batch:=MultiMesh.new()
			batch.transform_format=MultiMesh.TRANSFORM_3D
			batch.mesh=mesh
			batch.instance_count=transforms.size()
			for i in transforms.size():batch.set_instance_transform(i,transforms[i])
			var item:=MultiMeshInstance3D.new()
			item.multimesh=batch
			item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(item)

func _make_tuft(material:Material)->Mesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var colors:=[Color("#709448"),Color("#7b964a"),Color("#648f46"),Color("#6e8b4c")]
	for i in 4:
		var x:=float(i)*.13-.2
		var h:=.21+.19*sin(i*1.45+.5)
		var base:=Vector3(x,0.,sin(i*1.2)*.18)
		var tip:=base+Vector3(.09*cos(i*1.3),h,.17)
		var bend:=base+Vector3(-.04,h*.61,.09)
		for p:Vector3 in [base,base+Vector3(.10,0.,0.),bend+Vector3(.11,0.,0.),base,bend+Vector3(.11,0.,0.),bend,bend,bend+Vector3(.11,0.,0.),tip]:
			tool.set_color(colors[i])
			tool.set_normal(Vector3.UP)
			tool.add_vertex(p)
	return tool.commit()
