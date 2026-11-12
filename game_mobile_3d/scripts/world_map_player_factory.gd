extends RefCounted
## Selects the same player for WorldMap and the isolated mechanics lab.
const ORIGINAL := preload("res://scenes/characters/CuboidPlayerJumpGifV004.tscn")
const PRIVATE_ADAPTER := "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"

static func uses_private_player() -> bool:
	return OS.get_environment("GAF_SHOWCASE_PLAYER") != "original"

static func create(use_private: bool) -> CharacterBody3D:
	if use_private and OS.has_feature("editor") and ResourceLoader.exists(PRIVATE_ADAPTER):
		return load(PRIVATE_ADAPTER).new()
	var player := ORIGINAL.instantiate() as CharacterBody3D
	if use_private:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	return player
