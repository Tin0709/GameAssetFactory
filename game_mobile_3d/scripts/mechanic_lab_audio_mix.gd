extends Node

enum Layer { MASTER, WEAPON, ZOMBIE, SURFACE }

var _buses: Array[StringName] = []

func _ready() -> void:
	for layer in Layer.size():
		var bus := StringName("MechanicLab_%d_%d" % [get_instance_id(), layer])
		AudioServer.add_bus()
		var index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master" if layer == Layer.MASTER else _buses[Layer.MASTER])
		_buses.append(bus)

func bus_name(layer: int) -> StringName:
	return _buses[layer]

func set_level(layer: int, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name(layer))
	if index < 0:
		return
	if percent > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(percent * 0.01))
	AudioServer.set_bus_mute(index, percent <= 0.0)

func _exit_tree() -> void:
	for layer in range(_buses.size() - 1, -1, -1):
		var index := AudioServer.get_bus_index(_buses[layer])
		if index >= 0:
			AudioServer.remove_bus(index)
	_buses.clear()
