extends RefCounted
## Loads the private PlainsA1 ground plants and seats the authored cell placements.
const NativePlant := preload("forest_cover_grass.gd")
const MANIFEST := "godot_lab/world_map_unified_showcase_v001/plains_ground_planting_v001/sources.private.json"
const MANIFEST_SHA := "2e8f5e4d8f796a052be23155f2ae668c9bb527cc0efb2d8280ea76492547a837"
const SHRUB_SCALE := .85

var cells: Dictionary[Vector2i, Dictionary] = {}
var reserved: Dictionary[Vector2i, bool] = {}
var shrub_roots: Dictionary[Vector2i, Transform3D] = {}
var _source: RefCounted

func setup(world: Node3D, bundle: RefCounted) -> void:
	var recipe_file: String = world.plains_planting_path
	if recipe_file.is_empty() or not recipe_file.begins_with("res://") or not FileAccess.file_exists(recipe_file):
		return
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(recipe_file))
	if not recipe is Dictionary or recipe.get("schema") != 1 or not recipe.get("cells") is Array:
		return
	if recipe.get("layout_sha256") != FileAccess.get_sha256(world.map_layout_path):
		return
	var path: String = bundle.root.path_join(MANIFEST)
	if not bundle.permitted(path) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != MANIFEST_SHA:
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var directory: String = bundle.root.path_join(manifest.source_directory)
	var atlas_materials: Dictionary[String, ShaderMaterial] = {}
	var variants: Dictionary[int, Dictionary] = {}
	for item: Array in recipe.cells:
		if item.size() != 4 or int(item[2]) < 0 or int(item[2]) >= manifest.meshes.size():
			continue
		var index := int(item[2])
		if not variants.has(index):
			variants[index] = _load_variant(bundle, directory, manifest.meshes[index], manifest.atlases, atlas_materials)
		if not variants[index].is_empty():
			var cell := Vector2i(int(item[0]), int(item[1]))
			var row := variants[index].duplicate()
			row.turn = posmod(int(item[3]), 4)
			cells[cell] = row
	_source = bundle

func _load_variant(bundle: RefCounted, directory: String, row: Dictionary, atlas_rows: Dictionary,
		materials: Dictionary[String, ShaderMaterial]) -> Dictionary:
	var kind: String = row.atlas
	if not materials.has(kind):
		var file: Dictionary = atlas_rows[kind]
		var texture_path := _checked_asset(bundle, directory, file, "png")
		var image := Image.load_from_file(texture_path) if not texture_path.is_empty() else null
		if image == null or image.is_empty():
			return {}
		var material := NativePlant.plant_material(bundle, image)
		material.set_shader_parameter("tinted_grass", kind in ["cover", "straw"])
		if kind == "flowers" or kind == "shrub":
			material.set_meta("plains_foliage_transmission", .10 if kind == "flowers" else .06)
			var color_mips := _foliage_color_mips(image)
			if color_mips != null:
				material.set_meta("plains_foliage_color_mips", color_mips)
		if kind == "straw":
			material.set_meta("night_turf_weight", .55)
		if kind == "flowers":
			material.set_meta("plains_flower", true)
		if kind == "shrub":
			material.set_meta("plains_shrub", true)
		materials[kind] = material
		bundle.materials.append(material)
	var mesh := NativePlant.load_mesh(_checked_asset(bundle, directory, row, "glb"),
		materials[kind], true, Vector2(.35, 3.25))
	if mesh == null:
		return {}
	var asset: String = "PlainsA1 | " + row.id
	bundle.meshes[asset] = mesh
	return {"asset":asset,"kind":kind,"flower":String(row.color)}

func _foliage_color_mips(source: Image) -> ImageTexture:
	# Premultiply linear RGB so discarded texels cannot bleed into small petals.
	var mip := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var texel := source.get_pixel(x,y).srgb_to_linear()
			mip.set_pixel(x,y,Color(texel.r*texel.a,texel.g*texel.a,texel.b*texel.a,texel.a))
	if mip.generate_mipmaps() != OK:
		return null
	return ImageTexture.create_from_image(mip)

func _checked_asset(bundle: RefCounted, directory: String, row: Dictionary, extension: String) -> String:
	var relative: String = row.relative
	return NativePlant.checked_file(bundle, directory.path_join(relative.get_base_dir()),
		{"file":relative.get_file(),"sha256":row.sha256},extension)

func reserve_shrubs(world: Node3D, ferns: Dictionary, fern_support: Dictionary, clear_margin: Callable) -> void:
	reserved.clear()
	shrub_roots.clear()
	var offset: Array = world.runtime.offset
	for cell: Vector2i in cells:
		var row := cells[cell]
		if row.kind != "shrub":
			continue
		var center := Vector3(cell.x+.5, world.surface_height(cell.x+.5,cell.y+.5), cell.y+.5)
		if not center.is_finite():
			continue
		var pose := transform_at(cell, center.y, row)
		var mesh: Mesh = _source.meshes[row.asset]
		var aabb: AABB = (pose * mesh.get_aabb()).grow(.08)
		var supports: Array[Vector2i] = []
		var clear := true
		for x in range(floori(aabb.position.x), floori(aabb.end.x) + 1):
			for z in range(floori(aabb.position.z), floori(aabb.end.z) + 1):
				var footprint := Vector2i(x,z)
				var column := footprint - Vector2i(int(offset[0]),int(offset[2]))
				var y: float = world.columns.get(column,-INF)
				var index: int = world.geometry.cells.get(Vector3i(column.x,floori(y-.01),column.y),-1) if is_finite(y) else -1
				if (index < 0 or not String(world.runtime.palette[index].kind).begins_with("grass_")
						or not is_equal_approx(y+float(offset[1]),center.y) or not world.clear_standing_space(column,y)
						or not clear_margin.call(footprint) or ferns.has(footprint) or fern_support.has(footprint)
						or reserved.has(footprint) or shrub_roots.has(footprint)
						or (footprint != cell and cells.has(footprint))):
					clear = false
				elif footprint != cell:
					supports.append(footprint)
		if clear:
			shrub_roots[cell] = pose
			for support: Vector2i in supports:
				reserved[support] = true

func transform_at(cell: Vector2i, height: float, row: Dictionary) -> Transform3D:
	var mesh: Mesh = _source.meshes[row.asset]
	var bounds := mesh.get_aabb()
	var yaw: float = float(row.turn) * PI * .5
	var rotation := Basis(Vector3.UP,yaw)
	var rotated := Transform3D(rotation,Vector3.ZERO)*bounds
	var scale := minf(1.,.88/maxf(rotated.size.x,rotated.size.z))
	if row.kind == "shrub":
		# Use the same reference scale for every shrub and retain the native size differences.
		scale = SHRUB_SCALE
	elif row.kind == "flowers":
		scale = minf(scale,.74/bounds.size.y)
	var basis := rotation.scaled(Vector3.ONE*scale)
	var pivot := bounds.get_center()
	pivot.y = bounds.position.y
	return Transform3D(basis,Vector3(cell.x+.5,height,cell.y+.5)-basis*pivot)
