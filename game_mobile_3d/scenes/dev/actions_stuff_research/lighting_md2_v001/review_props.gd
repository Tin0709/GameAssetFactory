extends Node3D
## Small linked evaluation arrangement; no source meshes/materials are edited.
const BASE:="res://assets/environment/"

func _ready()->void:
	name="ExistingAssetLightingEvaluation"
	_block("world_map_v1/stone_block.glb",Vector3(-4.6,0,-1.6))
	_block("world_map_v1/stone_block.glb",Vector3(-4.6,1,-1.6))
	_block("world_map_v1/dirt_block.glb",Vector3(-3.6,0,-1.6))
	_model("world_map_v1/flower_white.glb",Vector3(-3.6,1,-1.6),false)
	_block("world_map_v1/grass_block.glb",Vector3(3.8,0,-3.0))
	_model("world_map_v1/flower_yellow.glb",Vector3(3.8,1,-3.0),false)
	_model("world_map_v1/flower_red.glb",Vector3(3.4,1,-3.2),false)
	for at:Vector3 in [Vector3(-4.8,0,-5.8),Vector3(5.8,0,-6.8)]:
		_model("forest_canopy_v3/tree_oak_a.glb",at,true)
		_box(at+Vector3(0,1.3,0),Vector3(.55,2.6,.55))

func _model(path:String,at:Vector3,shadows:bool)->Node3D:
	var node:Node3D=load(BASE+path).instantiate();node.position=at;add_child(node)
	for mesh:Node in node.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
func _block(path:String,at:Vector3)->void:
	_model(path,at,true);_box(at+Vector3(0,.5,0),Vector3.ONE)
func _box(at:Vector3,size:Vector3)->void:
	var body:=StaticBody3D.new();body.position=at;add_child(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
