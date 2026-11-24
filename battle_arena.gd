extends Node2D

@export var grid_position := Vector2(-350.4, 76.6)
@export var grid_scale := Vector2(1.6387, 0.9258)
@export var cell_hitbox_size := Vector2(60, 60)
@export var cell_visual_size := Vector2(60, 60)
@export var use_template_layout := false
@export var training_battle := false
@export var cell_spacing := Vector2(64, 64)

var selected_unit: Area2D
var highlighted_cells: Array[Area2D] = []
var attack_targets: Array[Area2D] = []
var inspected_unit: Area2D
enum Turn { PLAYER, AI }
var current_turn := Turn.PLAYER
var battle_finished := false
@onready var instruction_label: Label = $InstructionLabel
@onready var result_layer: Control = $BattleResultLayer
@onready var result_title: Label = $BattleResultLayer/ResultPanel/ResultTitle
@onready var retry_button: Button = $BattleResultLayer/ResultPanel/RetryButton
@onready var map_button: Button = $BattleResultLayer/ResultPanel/MapButton
@onready var result_back_button: Button = $BattleResultLayer/ResultPanel/BackButton
@onready var menu_layer: Control = $PauseMenuLayer/PauseMenuRoot
@onready var menu_button: Button = $PauseMenuLayer/PauseMenuRoot/MenuButton
@onready var menu_panel: Panel = $PauseMenuLayer/PauseMenuRoot/MenuPanel
@onready var surrender_button: Button = $PauseMenuLayer/PauseMenuRoot/MenuPanel/SurrenderButton
@onready var settings_button: Button = $PauseMenuLayer/PauseMenuRoot/MenuPanel/SettingsButton
@onready var continue_button: Button = $PauseMenuLayer/PauseMenuRoot/MenuPanel/ContinueButton
@onready var items_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsButton
@onready var items_drawer: Panel = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer
@onready var items_title: Label = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/DrawerTitle
@onready var medkit_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/MedkitButton
@onready var strength_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/StrengthButton
@onready var bomb_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/BombButton
@onready var brick_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/BrickButton
@onready var adrenaline_button: Button = $PauseMenuLayer/PauseMenuRoot/ItemsDrawer/AdrenalineButton
var medkit_description: Label
var strength_description: Label
var bomb_description: Label
var brick_description: Label
var adrenaline_description: Label

var selecting_item := ""
var player_action_count := 0
var player_acted_units: Array[Area2D] = []
var player_action_limit_override := 0
var player_action_limit_base := 0
const MAX_ITEMS_PER_TURN := 2
var items_used_this_turn := 0
var training_item_counts: Dictionary[String, int] = {}
var cancel_item_button: Button

func _enter_tree() -> void:
	add_to_group("battle_arena")

func _ready() -> void:
	if training_battle:
		for item_id in GameState.BATTLE_ITEMS:
			training_item_counts[item_id] = GameState.BATTLE_ITEMS[item_id].initial
	$Cells.position = grid_position
	$Cells.scale = grid_scale
	$Units.position = grid_position
	$Units.scale = grid_scale
	recalculate_base_player_action_limit()
	if use_template_layout:
		normalize_from_templates()

	for cell in $Cells.get_children():
		configure_cell_hitbox(cell)
		configure_cell_visual(cell)
		cell.cell_pressed.connect(_on_cell_pressed)

	for unit in $Units.get_children():
		if not training_battle and unit.team == "enemy":
			var balance: Dictionary = GameState.DIFFICULTIES[GameState.difficulty]
			unit.max_hp = maxi(1, roundi(unit.max_hp * balance.hp))
			unit.attack = maxi(1, roundi(unit.attack * balance.attack))
		unit.unit_pressed.connect(_on_unit_pressed)
		unit.defeated.connect(_on_unit_defeated)
		align_unit_to_cell(unit)

	retry_button.pressed.connect(_on_retry_pressed)
	map_button.pressed.connect(_on_map_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	surrender_button.pressed.connect(_on_surrender_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	items_button.pressed.connect(_on_items_pressed)
	medkit_button.pressed.connect(_on_medkit_pressed)
	strength_button.pressed.connect(_on_strength_pressed)
	bomb_button.pressed.connect(_on_bomb_pressed)
	brick_button.pressed.connect(_on_brick_pressed)
	adrenaline_button.pressed.connect(_on_adrenaline_pressed)
	setup_item_icons()
	setup_item_cancel_button()
	result_layer.visible = false
	result_back_button.visible = false
	menu_layer.visible = true
	menu_panel.visible = false
	items_drawer.visible = false
	update_item_buttons()
	if get_tree().has_meta("open_battle_menu"):
		get_tree().remove_meta("open_battle_menu")
		menu_panel.visible = true
	update_turn_label()

func configure_cell_hitbox(cell: Area2D) -> void:
	var collision_shape := cell.get_node("CollisionShape2D") as CollisionShape2D
	var touch_button := cell.get_node("TouchScreenButton") as TouchScreenButton
	var collision_rectangle := collision_shape.shape.duplicate() as RectangleShape2D
	var button_rectangle := touch_button.shape.duplicate() as RectangleShape2D

	collision_rectangle.size = cell_hitbox_size
	button_rectangle.size = cell_hitbox_size
	collision_shape.shape = collision_rectangle
	touch_button.shape = button_rectangle

func configure_cell_visual(cell: Area2D) -> void:
	var tile := cell.get_node("Tile") as Polygon2D
	var half_size := cell_visual_size / 2.0
	tile.polygon = PackedVector2Array([
		-half_size,
		Vector2(half_size.x, -half_size.y),
		half_size,
		Vector2(-half_size.x, half_size.y)
	])

func align_unit_to_cell(unit: Area2D) -> void:
	var cell := get_cell_by_position(unit.cell)
	if cell != null:
		unit.global_position = cell.global_position

func get_cell_by_position(cell_position: Vector2i) -> Area2D:
	for cell in $Cells.get_children():
		if cell.grid_position == cell_position:
			return cell
	return null

func normalize_from_templates() -> void:
	var cell_template := $Cells.get_node_or_null("Cell07") as Area2D
	var unit_template := $Units.get_node_or_null("Player1") as Area2D
	if cell_template == null or unit_template == null:
		return

	for cell in $Cells.get_children():
		var offset: Vector2i = cell.grid_position - cell_template.grid_position
		cell.position = cell_template.position + Vector2(
			offset.x * cell_spacing.x,
			offset.y * cell_spacing.y
		)
		cell.rotation = cell_template.rotation
		cell.scale = Vector2(0.9, 0.9)
		cell.z_index = cell_template.z_index
		cell.modulate = cell_template.modulate
		copy_template_children(cell_template, cell)

	for unit in $Units.get_children():
		unit.rotation = unit_template.rotation
		unit.scale = unit_template.scale
		unit.z_index = unit_template.z_index
		unit.modulate = unit_template.modulate
		copy_template_children(unit_template, unit)

func copy_template_children(template_node: Node, target_node: Node) -> void:
	for template_child in template_node.get_children():
		var target_child := target_node.get_node_or_null(NodePath(template_child.name))
		if target_child == null:
			continue
		if target_child is Node2D:
			var template_node2d := template_child as Node2D
			var target_node2d := target_child as Node2D
			target_node2d.position = template_node2d.position
			target_node2d.rotation = template_node2d.rotation
			target_node2d.scale = template_node2d.scale
			target_node2d.z_index = template_node2d.z_index
			target_node2d.modulate = template_node2d.modulate
			target_node2d.visible = template_node2d.visible

func _on_unit_pressed(unit: Area2D) -> void:
	if battle_finished or current_turn != Turn.PLAYER:
		return

	if selecting_item != "":
		if unit.team == "enemy" and selecting_item == "bomb" and unit.visible and unit.hp > 0:
			_use_bomb_on_target(unit)
		elif unit.team == "enemy" and selecting_item == "brick" and unit.visible and unit.hp > 0:
			_use_brick_on_target(unit)
		elif unit.team == "player" and selecting_item != "bomb" and unit.visible and unit.hp > 0:
			_use_support_item_on_target(unit)
		return

	if selected_unit == unit:
		unit.set_stats_visible(false)
		inspected_unit = null
		clear_selection()
		return

	if unit.team == "player" and unit in player_acted_units:
		instruction_label.text = "Этот персонаж уже походил\nОсталось действий: %d" % (get_player_action_limit() - player_action_count)
		return

	if inspected_unit != null and inspected_unit != unit:
		inspected_unit.set_stats_visible(false)

	unit.set_stats_visible(true)
	inspected_unit = unit

	if selected_unit != null and unit in attack_targets:
		attack_selected_unit(unit)
		return

	if unit.team != "player":
		return

	if selected_unit == unit:
		clear_selection()
		return

	select_unit(unit)

func _on_cell_pressed(cell: Area2D) -> void:
	if battle_finished or selected_unit == null:
		return
	if not cell in highlighted_cells:
		return

	var acting_unit := selected_unit
	acting_unit.cell = cell.grid_position
	acting_unit.global_position = cell.global_position
	clear_selection()
	hide_inspected_stats()
	complete_player_action(acting_unit)

func select_unit(unit: Area2D) -> void:
	if unit in player_acted_units:
		instruction_label.text = "Этот персонаж уже походил\nОсталось действий: %d" % (get_player_action_limit() - player_action_count)
		return
	clear_selection()
	selected_unit = unit

	for cell in $Cells.get_children():
		if abs(cell.grid_position.x - unit.cell.x) <= 1 \
		and abs(cell.grid_position.y - unit.cell.y) <= 1 \
		and cell.grid_position != unit.cell \
		and is_cell_free(cell.grid_position):
			cell.set_highlighted(true)
			highlighted_cells.append(cell)

	for enemy in $Units.get_children():
		if enemy.team == "enemy" \
		and abs(enemy.cell.x - unit.cell.x) <= 1 \
		and abs(enemy.cell.y - unit.cell.y) <= 1 \
		and enemy.cell != unit.cell \
		and enemy.visible:
			enemy.set_attackable(true)
			attack_targets.append(enemy)

	unit.set_selected(true)
	instruction_label.text = "Выберите клетку или врага\nХод игрока"

func clear_selection() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)

	for cell in highlighted_cells:
		cell.set_highlighted(false)

	for enemy in attack_targets:
		enemy.set_attackable(false)

	highlighted_cells.clear()
	attack_targets.clear()
	selected_unit = null
	update_turn_label()

func hide_inspected_stats() -> void:
	if inspected_unit != null:
		inspected_unit.set_stats_visible(false)
		inspected_unit = null

func attack_selected_unit(target: Area2D) -> void:
	var damage: int = selected_unit.attack
	var acting_unit := selected_unit
	target.show_damage(damage)
	target.take_damage(damage)
	check_battle_result()
	instruction_label.text = "%s получил %d урона" % [target.name, damage]
	clear_selection()
	hide_inspected_stats()
	if target.hp > 0:
		target.set_stats_visible(true)
		inspected_unit = target
	if not battle_finished:
		complete_player_action(acting_unit)

func complete_player_action(unit: Area2D) -> void:
	var adrenaline_actions: int = unit.get_meta("adrenaline_actions_remaining", 0)
	if adrenaline_actions > 0:
		adrenaline_actions -= 1
		unit.set_meta("adrenaline_actions_remaining", adrenaline_actions)
		if adrenaline_actions == 0:
			player_acted_units.append(unit)
	else:
		if not unit in player_acted_units:
			player_acted_units.append(unit)
	player_action_count += 1
	unit.set_selected(false)

	var action_limit := get_player_action_limit()
	if player_action_count >= action_limit:
		end_player_turn()
	else:
		instruction_label.text = "Ход другого персонажа\nОсталось действий: %d" % (action_limit - player_action_count)

func end_player_turn() -> void:
	current_turn = Turn.AI
	clear_selection()
	update_turn_label()
	await get_tree().create_timer(0.5).timeout
	run_ai_turn()

func run_ai_turn() -> void:
	if battle_finished:
		return
	instruction_label.text = "Ход ИИ"
	for enemy in $Units.get_children():
		if battle_finished:
			break
		if enemy.team != "enemy" or not enemy.visible or enemy.hp <= 0:
			continue
		await run_enemy_turn(enemy)

	current_turn = Turn.PLAYER
	player_action_count = 0
	items_used_this_turn = 0
	player_acted_units.clear()
	player_action_limit_override = 0
	for unit in $Units.get_children():
		if unit.team == "player" and unit.visible and unit.hp > 0:
			if unit.get_meta("skip_next_turn", false):
				unit.set_meta("skip_next_turn", false)
				unit.set_meta("adrenaline_active", false)
				unit.set_meta("adrenaline_used_this_turn", false)
				player_acted_units.append(unit)
			else:
				unit.set_meta("adrenaline_used_this_turn", false)
			unit.set_meta("adrenaline_actions_remaining", 0)
			var strength_turns: int = unit.get_meta("strength_turns", 0)
			if strength_turns > 0:
				strength_turns -= 1
				if strength_turns == 0:
					unit.attack -= 15
					unit.update_stats_label()
				unit.set_meta("strength_turns", strength_turns)
	recalculate_base_player_action_limit()
	if get_player_action_limit() <= 0:
		instruction_label.text = "Все персонажи пропускают ход"
		call_deferred("end_player_turn")
		return
	update_turn_label()

func get_player_action_limit() -> int:
	if player_action_limit_override > 0:
		return player_action_limit_override
	return player_action_limit_base

func recalculate_base_player_action_limit() -> void:
	var alive_players := 0
	for unit in $Units.get_children():
		if unit.team == "player" and unit.visible and unit.hp > 0:
			alive_players += 1
	var available_players := alive_players
	for unit in player_acted_units:
		if unit.team == "player" and unit.visible and unit.hp > 0:
			available_players -= 1
	var action_limit: int = 2 if training_battle else GameState.DIFFICULTIES[GameState.difficulty].actions
	player_action_limit_base = mini(available_players, action_limit)

func run_enemy_turn(enemy: Area2D) -> void:
	var stunned_turns: int = enemy.get_meta("stunned_turns", 0)
	if stunned_turns > 0:
		enemy.set_meta("stunned_turns", stunned_turns - 1)
		instruction_label.text = "%s оглушён и пропускает ход" % enemy.name
		await get_tree().create_timer(0.45).timeout
		return

	var adjacent_target := choose_adjacent_player(enemy)
	if adjacent_target != null:
		enemy.set_attackable(true)
		await get_tree().create_timer(0.25).timeout
		enemy.set_attackable(false)
		adjacent_target.show_damage(enemy.attack)
		adjacent_target.take_damage(enemy.attack)
		instruction_label.text = "%s атакует %s" % [enemy.name, adjacent_target.name]
		check_battle_result()
		await get_tree().create_timer(0.45).timeout
		return

	var target := choose_best_player_target(enemy)
	if target == null:
		return

	var next_cell := choose_best_move_cell(enemy, target)
	if next_cell != null:
		enemy.cell = next_cell.grid_position
		enemy.global_position = next_cell.global_position
		instruction_label.text = "%s перемещается" % enemy.name
		await get_tree().create_timer(0.35).timeout

func choose_adjacent_player(enemy: Area2D) -> Area2D:
	var best_target: Area2D
	var best_score := INF
	for unit in $Units.get_children():
		if unit.team != "player" or not unit.visible or unit.hp <= 0:
			continue
		if not is_adjacent(enemy.cell, unit.cell):
			continue
		var score := get_target_score(enemy, unit)
		if score < best_score:
			best_score = score
			best_target = unit
	return best_target

func choose_best_player_target(enemy: Area2D) -> Area2D:
	var best_target: Area2D
	var best_score := INF
	for unit in $Units.get_children():
		if unit.team != "player" or not unit.visible or unit.hp <= 0:
			continue
		var score := get_target_score(enemy, unit)
		if score < best_score:
			best_score = score
			best_target = unit
	return best_target

func get_target_score(enemy: Area2D, target: Area2D) -> float:
	var distance: int = abs(enemy.cell.x - target.cell.x) + abs(enemy.cell.y - target.cell.y)
	# Сначала сближаемся, затем выбираем слабую и опасную цель.
	return distance * 10.0 + target.hp * 0.25 - target.attack * 0.5

func choose_best_move_cell(enemy: Area2D, target: Area2D) -> Area2D:
	var best_cell: Area2D
	var best_score := INF
	for cell in $Cells.get_children():
		if not is_adjacent(enemy.cell, cell.grid_position):
			continue
		if not is_cell_free(cell.grid_position):
			continue
		var distance: int = abs(cell.grid_position.x - target.cell.x) \
			+ abs(cell.grid_position.y - target.cell.y)
		var score: float = distance * 10.0
		if is_adjacent(cell.grid_position, target.cell):
			score -= 5.0
		if score < best_score:
			best_score = score
			best_cell = cell
	return best_cell

func is_adjacent(first: Vector2i, second: Vector2i) -> bool:
	return first != second \
		and abs(first.x - second.x) <= 1 \
		and abs(first.y - second.y) <= 1

func _on_unit_defeated(_unit: Area2D) -> void:
	if _unit in player_acted_units:
		player_acted_units.erase(_unit)
	check_battle_result()
	reconcile_player_actions()

func reconcile_player_actions() -> void:
	if battle_finished or current_turn != Turn.PLAYER:
		return
	recalculate_base_player_action_limit()
	var action_limit := get_player_action_limit()
	if action_limit <= 0:
		return
	for unit in player_acted_units.duplicate():
		if unit.team == "player" and (not unit.visible or unit.hp <= 0):
			player_acted_units.erase(unit)
	if player_action_count >= action_limit:
		end_player_turn()

func check_battle_result() -> void:
	if battle_finished:
		return

	var players_alive := false
	var enemies_alive := false
	for unit in $Units.get_children():
		if unit.hp <= 0:
			continue
		if unit.team == "player":
			players_alive = true
		elif unit.team == "enemy":
			enemies_alive = true

	if not enemies_alive:
		show_victory()
	elif not players_alive:
		show_defeat()

func show_victory() -> void:
	battle_finished = true
	clear_selection()
	if training_battle:
		GameState.complete_level(GameState.TRAINING_LEVEL)
		result_title.text = "ОБУЧЕНИЕ ПРОЙДЕНО"
	else:
		GameState.complete_current_level()
		result_title.text = "ПОБЕДА!"
	retry_button.visible = false
	map_button.visible = true
	result_back_button.visible = false
	result_layer.visible = true

func show_defeat() -> void:
	battle_finished = true
	clear_selection()
	result_title.text = "ПОРАЖЕНИЕ"
	retry_button.visible = true
	map_button.visible = true
	result_back_button.visible = true
	result_layer.visible = true

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://Global_Map.tscn")

func _on_result_back_pressed() -> void:
	result_layer.visible = false
	result_back_button.visible = false
	battle_finished = false
	menu_panel.visible = true
	update_turn_label()

func _on_menu_pressed() -> void:
	if not battle_finished:
		items_drawer.visible = false
		menu_panel.visible = true

func _on_surrender_pressed() -> void:
	menu_panel.visible = false
	show_defeat()

func _on_settings_pressed() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		get_tree().set_meta("settings_return_scene", current_scene.scene_file_path)
	get_tree().set_meta("open_battle_menu", true)
	get_tree().change_scene_to_file("res://settings.tscn")

func _on_continue_pressed() -> void:
	menu_panel.visible = false

func _on_items_pressed() -> void:
	menu_panel.visible = false
	items_drawer.visible = not items_drawer.visible
	if items_drawer.visible:
		update_item_buttons()

func _on_medkit_pressed() -> void:
	if not can_use_item() or _get_item_count("medkit") <= 0:
		return
	if not start_item_target_selection("medkit"):
		return

func _on_strength_pressed() -> void:
	if not can_use_item() or _get_item_count("strength") <= 0:
		return
	if not start_item_target_selection("strength"):
		return

func _on_bomb_pressed() -> void:
	if not can_use_item() or _get_item_count("bomb") <= 0:
		return
	clear_selection()
	selecting_item = "bomb"
	var enemy_found := false
	for unit in $Units.get_children():
		if unit.team == "enemy" and unit.visible and unit.hp > 0:
			unit.set_attackable(true)
			attack_targets.append(unit)
			enemy_found = true
	if not enemy_found:
		selecting_item = ""
		return

	items_drawer.visible = false
	instruction_label.text = "Выберите врага для бомбы"
	cancel_item_button.visible = true

func _on_brick_pressed() -> void:
	if not can_use_item() or _get_item_count("brick") <= 0:
		return
	clear_selection()
	selecting_item = "brick"
	var enemy_found := false
	for unit in $Units.get_children():
		if unit.team == "enemy" and unit.visible and unit.hp > 0:
			unit.set_attackable(true)
			attack_targets.append(unit)
			enemy_found = true
	if not enemy_found:
		selecting_item = ""
		return
	items_drawer.visible = false
	instruction_label.text = "Выберите противника для кирпича"
	cancel_item_button.visible = true

func _on_adrenaline_pressed() -> void:
	if not can_use_item() or _get_item_count("adrenaline") <= 0:
		return
	if not start_item_target_selection("adrenaline"):
		return

func _use_bomb_on_target(target: Area2D) -> void:
	var target_cell: Vector2i = target.cell
	target.show_damage(30)
	target.take_damage(30)
	for enemy in $Units.get_children():
		if enemy == target \
		or enemy.team != "enemy" \
		or not enemy.visible \
		or enemy.hp <= 0 \
		or not is_adjacent(target_cell, enemy.cell):
			continue
		enemy.show_damage(15)
		enemy.take_damage(15)
	_consume_item("bomb")
	items_used_this_turn += 1
	selecting_item = ""
	cancel_item_button.visible = false
	for enemy in attack_targets:
		enemy.set_attackable(false)
	attack_targets.clear()
	instruction_label.text = "Бомба нанесла 30 урона %s и 15 соседним врагам" % target.name
	items_drawer.visible = false
	update_item_buttons()
	check_battle_result()
	if not battle_finished:
		instruction_label.text = "Бомба использована\nДействия персонажей: %d/%d" % [player_action_count, get_player_action_limit()]

func start_item_target_selection(item_name: String) -> bool:
	clear_selection()
	selecting_item = item_name
	var player_found := false
	for unit in $Units.get_children():
		if unit.team == "player" and unit.visible and unit.hp > 0:
			if item_name == "adrenaline":
				if unit in player_acted_units:
					continue
				if unit.get_meta("adrenaline_active", false):
					continue
				if unit.get_meta("adrenaline_used_this_turn", false):
					continue
			unit.set_attackable(true)
			attack_targets.append(unit)
			player_found = true
	if not player_found:
		selecting_item = ""
		return false
	items_drawer.visible = false
	instruction_label.text = "Выберите союзника для предмета"
	cancel_item_button.visible = true
	return true

func _use_brick_on_target(target: Area2D) -> void:
	target.set_meta("stunned_turns", 1)
	_consume_item("brick")
	items_used_this_turn += 1
	selecting_item = ""
	cancel_item_button.visible = false
	for enemy in attack_targets:
		enemy.set_attackable(false)
	attack_targets.clear()
	instruction_label.text = "%s оглушён на один ход" % target.name
	items_drawer.visible = false
	update_item_buttons()

func _use_support_item_on_target(target: Area2D) -> void:
	if selecting_item == "medkit":
		if target.hp >= target.max_hp:
			instruction_label.text = "У персонажа уже полное здоровье"
			_cancel_item_target_selection()
			return
		target.hp = mini(target.max_hp, target.hp + 50)
		target.update_stats_label()
		target.show_effect(50, "heal")
		target.set_stats_visible(true)
		_consume_item("medkit")
		instruction_label.text = "%s восстановил 50 HP" % target.name
	elif selecting_item == "strength":
		if target.get_meta("strength_turns", 0) <= 0:
			target.attack += 15
		target.set_meta("strength_turns", 2)
		target.update_stats_label()
		target.show_effect(15, "attack")
		target.set_stats_visible(true)
		_consume_item("strength")
		instruction_label.text = "%s получил Медавуху: +15 ATK на 2 хода" % target.name
	elif selecting_item == "adrenaline":
		if target in player_acted_units:
			instruction_label.text = "Этот персонаж уже использовал действие в этом ходу"
			_cancel_item_target_selection()
			return
		if target.get_meta("adrenaline_active", false):
			instruction_label.text = "На этого персонажа уже действует Энергетик Адреналин"
			_cancel_item_target_selection()
			return
		if target.get_meta("adrenaline_used_this_turn", false):
			instruction_label.text = "Адреналин уже применялся к этому персонажу в этом ходу"
			_cancel_item_target_selection()
			return
		target.set_meta("adrenaline_actions_remaining", 3)
		target.set_meta("skip_next_turn", true)
		target.set_meta("adrenaline_active", true)
		target.set_meta("adrenaline_used_this_turn", true)
		player_action_limit_override = get_player_action_limit() + 2
		_consume_item("adrenaline")
		target.set_stats_visible(true)
		instruction_label.text = "%s получил +2 действия; следующий ход пропускает" % target.name
	else:
		return

	items_used_this_turn += 1
	_cancel_item_target_selection()
	update_item_buttons()

func _cancel_item_target_selection() -> void:
	selecting_item = ""
	cancel_item_button.visible = false
	for unit in attack_targets:
		unit.set_attackable(false)
	attack_targets.clear()

func _on_cancel_item_pressed() -> void:
	if selecting_item.is_empty():
		return
	_cancel_item_target_selection()
	items_drawer.visible = true
	update_item_buttons()
	instruction_label.text = "Выбор предмета отменён"

func _get_item_count(item_id: String) -> int:
	if training_battle:
		return training_item_counts[item_id]
	return GameState.item_counts[item_id]


func _consume_item(item_id: String) -> void:
	if training_battle:
		training_item_counts[item_id] -= 1
	else:
		GameState.consume_battle_item(item_id)


func can_use_item() -> bool:
	return not battle_finished \
		and current_turn == Turn.PLAYER \
		and items_used_this_turn < MAX_ITEMS_PER_TURN

func update_item_buttons() -> void:
	items_title.text = "Предметы: %d/%d" % [items_used_this_turn, MAX_ITEMS_PER_TURN]
	medkit_description.text = "+50 HP  x%d" % _get_item_count("medkit")
	strength_description.text = "+15 ATK на 2 хода  x%d" % _get_item_count("strength")
	bomb_description.text = "30/15 урона  x%d" % _get_item_count("bomb")
	brick_description.text = "Оглушение  x%d" % _get_item_count("brick")
	adrenaline_description.text = "+2 действия  x%d" % _get_item_count("adrenaline")
	var item_limit_reached := items_used_this_turn >= MAX_ITEMS_PER_TURN
	medkit_button.disabled = _get_item_count("medkit") <= 0 or item_limit_reached
	strength_button.disabled = _get_item_count("strength") <= 0 or item_limit_reached
	bomb_button.disabled = _get_item_count("bomb") <= 0 or item_limit_reached
	brick_button.disabled = _get_item_count("brick") <= 0 or item_limit_reached
	adrenaline_button.disabled = _get_item_count("adrenaline") <= 0 or item_limit_reached

func setup_item_icons() -> void:
	medkit_description = setup_item_button(medkit_button, "medkit")
	strength_description = setup_item_button(strength_button, "strength")
	bomb_description = setup_item_button(bomb_button, "bomb")
	brick_description = setup_item_button(brick_button, "brick")
	adrenaline_description = setup_item_button(adrenaline_button, "adrenaline")

func setup_item_cancel_button() -> void:
	cancel_item_button = menu_layer.get_node_or_null("CancelItemButton") as Button
	if cancel_item_button == null:
		cancel_item_button = Button.new()
		cancel_item_button.name = "CancelItemButton"
		menu_layer.add_child(cancel_item_button)
	cancel_item_button.anchor_left = 1.0
	cancel_item_button.anchor_right = 1.0
	cancel_item_button.offset_left = -320.0
	cancel_item_button.offset_top = 18.0
	cancel_item_button.offset_right = -170.0
	cancel_item_button.offset_bottom = 68.0
	cancel_item_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cancel_item_button.text = "Отмена"
	cancel_item_button.visible = false
	if not cancel_item_button.pressed.is_connected(_on_cancel_item_pressed):
		cancel_item_button.pressed.connect(_on_cancel_item_pressed)

func setup_item_button(button: Button, item_id: String) -> Label:
	var item: Dictionary = GameState.BATTLE_ITEMS[item_id]
	button.text = ""

	var icon := button.get_node_or_null("ItemIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "ItemIcon"
		button.add_child(icon)
	icon.position = Vector2(10, 5)
	icon.size = Vector2(45, 45)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var name_label := button.get_node_or_null("ItemName") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "ItemName"
		button.add_child(name_label)
	name_label.position = Vector2(70, 5)
	name_label.size = Vector2(395, 23)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.text = item.name

	var description := button.get_node_or_null("ItemDescription") as Label
	if description == null:
		description = Label.new()
		description.name = "ItemDescription"
		button.add_child(description)
	description.position = Vector2(70, 30)
	description.size = Vector2(395, 18)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.add_theme_font_size_override("font_size", 11)
	return description

func update_turn_label() -> void:
	if current_turn == Turn.PLAYER:
		instruction_label.text = "Ход игрока\nДействия: %d/%d" % [player_action_count, get_player_action_limit()]
	else:
		instruction_label.text = "Ход ИИ"

func is_cell_free(cell_position: Vector2i) -> bool:
	for unit in $Units.get_children():
		if unit.visible and unit.cell == cell_position:
			return false
	return true
