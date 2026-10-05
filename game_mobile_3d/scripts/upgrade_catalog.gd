extends RefCounted
## A small data table targeting the existing player and weapon inspector stats.
const UPGRADES = [
 {"id": &"power_shot", "name": "POWER SHOT", "description": "Harder-hitting pistol rounds.", "effects": [
  {"target": "pistol", "property": "damage", "add": 5, "label": "Damage", "digits": 0}]},
 {"id": &"rapid_fire", "name": "RAPID FIRE", "description": "Reduce shot interval by 10%.", "effects": [
  {"target": "pistol", "property": "fire_interval", "multiply": 0.9, "minimum": 0.18, "label": "Shot interval", "unit": "s"}]},
 {"id": &"runner", "name": "RUNNER", "description": "Move 8% faster at both speeds.", "effects": [
  {"target": "player", "property": "walk_speed", "multiply": 1.08, "label": "Walk", "unit": "m/s"},
  {"target": "player", "property": "run_speed", "multiply": 1.08, "label": "Run", "unit": "m/s"}]},
 {"id": &"toughness", "name": "TOUGHNESS", "description": "Gain 20 max HP and heal 20 HP.", "heal": 20, "effects": [
  {"target": "player", "property": "max_hp", "add": 20, "label": "Max HP", "digits": 0}]},
 {"id": &"ballistics", "name": "BALLISTICS", "description": "Faster rounds with 10% more reach.", "effects": [
  {"target": "pistol", "property": "projectile_speed", "multiply": 1.1, "label": "Bullet speed", "unit": "m/s"},
  {"target": "pistol", "property": "projectile_range", "multiply": 1.1, "label": "Bullet travel", "unit": "m"},
  {"target": "pistol", "property": "attack_range", "multiply": 1.1, "label": "Target range", "unit": "m"}]}
]

static func next_value(effect: Dictionary, current: float) -> float:
	var result := (current + float(effect.get("add", 0))) * float(effect.get("multiply", 1))
	return maxf(float(effect.get("minimum", -INF)), result)

static func available(player: Node, pistol: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade: Dictionary in UPGRADES:
		var improves := false
		for effect: Dictionary in upgrade.effects:
			var target: Node = player if effect.target == "player" else pistol
			var current := float(target.get(effect.property))
			if not is_equal_approx(next_value(effect, current), current): improves = true
		if improves: result.append(upgrade)
	return result

static func apply(upgrade: Dictionary, player: Node, pistol: Node) -> void:
	for effect: Dictionary in upgrade.effects:
		var target: Node = player if effect.target == "player" else pistol
		var current: Variant = target.get(effect.property)
		var result := next_value(effect, float(current))
		target.set(effect.property, int(result) if typeof(current) == TYPE_INT else result)
	if upgrade.has("heal"):
		player.current_hp = mini(player.max_hp, player.current_hp + int(upgrade.heal))
		player.health_changed.emit(player.current_hp, player.max_hp)
	pistol.cooldown = minf(pistol.cooldown, pistol.fire_interval)

static func value_text(value: float, digits: int) -> String:
	return ("%." + str(digits) + "f") % value

static func card_text(upgrade: Dictionary, player: Node, pistol: Node) -> String:
	var result: String = upgrade.description + "\n"
	for effect: Dictionary in upgrade.effects:
		var target: Node = player if effect.target == "player" else pistol
		var current := float(target.get(effect.property))
		var digits := int(effect.get("digits", 2))
		result += "\n%s  %s → %s %s" % [effect.label, value_text(current, digits), value_text(next_value(effect, current), digits), effect.get("unit", "")]
	if upgrade.has("heal"):
		result += "\nCurrent HP  %d → %d" % [player.current_hp, mini(player.max_hp + int(upgrade.heal), player.current_hp + int(upgrade.heal))]
	return result
