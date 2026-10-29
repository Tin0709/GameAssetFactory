extends RefCounted
## Original bounded diffuse irradiance approximation for an instanced flat map.
## No shadow/AO stamps; no native GI operators, textures or LUTs are embedded.
const SIZE:=64
const EXTENT:=34.
const ORIGIN:=Vector2(-17,-17)
var image:Image
var texture:ImageTexture
func build(bundle:RefCounted,fields:Dictionary)->void:
	image=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBAH)
	var row:Dictionary=bundle.data.materials["OW MD2 | MI_MasterTerrain_Opaque_Overworld"]
	var atlas:Image=bundle.textures[row.texture].get_image()
	var grass_rect:=_top_rect(bundle,"MD2 RECON | Grass block 1")
	var dirt_rect:=_top_rect(bundle,"MD2 RECON | Dirt block 1")
	var sky:Vector3=fields.sky_fill_linear
	var gain:float=fields.ground_bounce_gain
	# Gather a broad, continuous color neighborhood rather than per-tile contacts.
	for y in SIZE:
		for x in SIZE:
			var world:=ORIGIN+(Vector2(x,y)+Vector2(.5,.5))*EXTENT/SIZE
			var bounce:=Vector3.ZERO
			for offset:Vector2 in [Vector2.ZERO,Vector2(.8,0),Vector2(-.8,0),Vector2(0,.8),Vector2(0,-.8)]:
				var p:=world+offset
				var center:=1.9*sin(p.y*.24)+.55*sin(p.y*.57)
				var grass:=smoothstep(.55,1.65,absf(p.x-center))
				var tile:=Vector2(fposmod(p.x,1.),fposmod(-p.y,1.))
				var c:=_read_color(atlas,dirt_rect,tile).lerp(_read_color(atlas,grass_rect,tile),grass)
				bounce+=Vector3(c.r,c.g,c.b)/5.
			var irradiance:=sky+bounce*gain
			image.set_pixel(x,y,Color(irradiance.x,irradiance.y,irradiance.z,1.))
	texture=ImageTexture.create_from_image(image)
func _top_rect(bundle:RefCounted,name:String)->Vector4:
	var lo:=Vector2.ONE;var hi:=Vector2.ZERO
	for entry:Dictionary in bundle.data.assets:
		if entry.name!=name:continue
		for s:Dictionary in entry.surfaces:
			for i in int(s.normals.size()/3):
				if float(s.normals[i*3+1])>.99:
					var uv:=Vector2(s.uv[i*2],s.uv[i*2+1]);lo=lo.min(uv);hi=hi.max(uv)
	return Vector4(lo.x,lo.y,hi.x,hi.y)
func _read_color(atlas:Image,rect:Vector4,tile:Vector2)->Color:
	var uv:=Vector2(lerpf(rect.x,rect.z,tile.x),lerpf(rect.y,rect.w,tile.y))
	return atlas.get_pixel(clampi(int(uv.x*atlas.get_width()),0,atlas.get_width()-1),clampi(int(uv.y*atlas.get_height()),0,atlas.get_height()-1)).srgb_to_linear()
func sample_fill(world_position:Vector3,_normal:Vector3)->Color:
	var uv:=(Vector2(world_position.x,world_position.z)-ORIGIN)/EXTENT
	return image.get_pixel(clampi(int(uv.x*SIZE),0,SIZE-1),clampi(int(uv.y*SIZE),0,SIZE-1))
