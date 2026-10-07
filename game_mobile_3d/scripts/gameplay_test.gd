extends Node3D

const WEAPON_SELECT = preload("res://scripts/weapon_test_select.gd")
const RESET_WEAPON_META = &"weapon_test_reset_selection"
const TEST_ENEMY = preload("res://scripts/animation_test_enemy.gd")
var animation_test_enemy: CharacterBody3D
var animation_test_active := false
var animation_review_mode := false
var weapon_selector: Control
var status_elapsed: float = 0.0
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat
@onready var progression: Node = $Progression
@onready var spawner: Node = $SpawnDirector

func _ready() -> void:
	$HUD/AnimationTestEnemyButton.pressed.connect(toggle_animation_test_enemy)
	$HUD/AnimationDebug.visible = OS.is_debug_build()
	if not OS.is_debug_build() or not progression.debug_exp_shortcut:
		$HUD/Help/Text.text = $HUD/Help/Text.text.replace("\nDebug: L level-up  |  K spawn 1  |  J spawn 10", "")
	player.health_changed.connect(_health_updated)
	player.exp_changed.connect(_exp_updated)
	weapon_selector = WEAPON_SELECT.new()
	weapon_selector.name = "WeaponTestSelect"
	weapon_selector.coordinator = self
	$HUD.add_child(weapon_selector)
	if get_tree().has_meta(RESET_WEAPON_META):
		player.equip_test_weapon(int(get_tree().get_meta(RESET_WEAPON_META)))
		get_tree().remove_meta(RESET_WEAPON_META)
	else:
		open_weapon_selector()
	update_status()

func toggle_animation_test_enemy() -> void:
	if player.is_dead or get_tree().paused: return
	if animation_test_active:
		if is_instance_valid(animation_test_enemy):
			combat.living_zombies.erase(animation_test_enemy)
			animation_test_enemy.queue_free()
		animation_test_enemy = null
		animation_test_active = false
		$HUD/AnimationTestEnemyButton.text = "Enemy test ở giữa map"
	else:
		animation_review_mode = true
		spawner.enabled = false
		# Remove ordinary threats without deaths, rewards or changing survival stats.
		for enemy in combat.living_zombies.duplicate():
			enemy.set_physics_process(false)
			combat.living_zombies.erase(enemy)
			enemy.queue_free()
		for bullet in combat.projectiles.get_children(): bullet.queue_free()
		animation_test_enemy = spawner.ZOMBIE.instantiate()
		animation_test_enemy.set_script(TEST_ENEMY)
		animation_test_enemy.name = "AnimationTestEnemy"
		animation_test_enemy.position = $Actors.to_local(Vector3(0, 0.02, 0))
		$Actors.add_child(animation_test_enemy)
		combat.register_zombie(animation_test_enemy)
		animation_test_active = true
		$HUD/AnimationTestEnemyButton.text = "Xóa enemy test"
	player.get_node("Pistol").cached_frame = -1
	update_status()

func open_weapon_selector() -> void:
	# A level-up selection owns its pause; never steal that selection's keys.
	if progression.selection_open or player.is_dead or get_tree().paused: return
	get_tree().paused = true
	weapon_selector.open()
	update_status()

func select_test_weapon(index: int) -> void:
	if not weapon_selector.visible or index < 0 or index > 2: return
	player.equip_test_weapon(index)
	weapon_selector.hide()
	get_tree().paused = false
	update_status()

func reset_run() -> void:
	# One-shot SceneTree metadata survives reload, without a production inventory.
	get_tree().set_meta(RESET_WEAPON_META, player.visual.weapon_type)
	get_tree().paused = false
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	if is_instance_valid(weapon_selector) and weapon_selector.visible:
		get_tree().paused = false

func _health_updated(_hp: int, _max_hp: int) -> void:
	update_status()

func _exp_updated(_exp: int) -> void:
	update_status()

func update_status() -> void:
	$HUD/AnimationTestEnemyButton.disabled = player.is_dead
	$HUD/AnimationTestEnemyStatus.visible = animation_review_mode
	$HUD/AnimationTestEnemyStatus.text = ("Đứng yên · không tấn công · bất tử\nXóa enemy để thử cất súng · R về gameplay" if animation_test_active else "Không có mục tiêu: thử cất súng\nBấm tạo enemy để rút súng · R về gameplay")
	var seconds := int(spawner.elapsed_survival)
	$HUD/Status.text = "Survived %02d:%02d  |  Alive %d / %d  |  Kills %d\nHP %d/%d  |  Level %d  |  %.2f m/s  |  %d FPS\n%s" % [
		seconds / 60, seconds % 60, combat.living_zombies.size(), spawner.max_active_zombies, combat.kill_count,
		player.current_hp, player.max_hp, player.level, player.current_speed, Engine.get_frames_per_second(),
		"Choose a test weapon — gameplay paused" if is_instance_valid(weapon_selector) and weapon_selector.visible else
		("Defeated — R to reset" if player.is_dead else ("Choose an upgrade" if progression.selection_open else
		("Next perimeter spawn incoming" if combat.living_zombies.is_empty() else "Auto-fire active  |  Shift to run")))]

	$HUD/ExpBar.max_value = progression.required_exp()
	$HUD/ExpBar.value = player.experience
	$HUD/ExpText.text = "EXP %d / %d" % [player.experience, progression.required_exp()]
	if OS.is_debug_build():
		$HUD/AnimationDebug.text = "Weapon: " + player.visual.debug_text() + "\n" + player.get_node("Pistol").debug_text() + "\n1 Pistol  |  2 M4A1  |  3 Shotgun  |  F2 Weapon Test Select"

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		reset_run()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_K: spawner.debug_spawn(1)
		elif event.physical_keycode == KEY_J: spawner.debug_spawn(10)
