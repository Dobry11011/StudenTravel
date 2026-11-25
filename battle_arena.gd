extends Node2D

@export var grid_position := Vector2(-350.4, 76.6)
@export var grid_scale := Vector2(1.6387, 0.9258)
@export var cell_hitbox_size := Vector2(60, 60)
@export var cell_visual_size := Vector2(60, 60)
@export var use_template_layout := false
@export var obstacles: Array[Vector2i] = []
@export var reinforcement_threshold := 0
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
@onready var defender: Area2D = $Units/Player1
@onready var striker: Area2D = $Units/Player2
@onready var item_buttons := {"medkit": medkit_button, "strength": strength_button, "bomb": bomb_button, "brick": brick_button, "adrenaline": adrenaline_button}

var selecting_item := ""
var player_action_count := 0
var items_used_this_turn := 0
var item_limit := 2
var stock: Dictionary[String, int] = {}
var cancel_item_button: Button
var mode := "attack"
var finisher_used := false
@onready var action_bar := HBoxContainer.new()
var commands := {}
var reserves: Array[Area2D] = []
var cells_by_position := {}
var neighbors_by_position: Dictionary[Vector2i, Array] = {}
@onready var cells := $Cells.get_children()
@onready var units := $Units.get_children()

func _enter_tree() -> void:
	add_to_group("battle_arena")

func _ready() -> void:
	var balance: Dictionary = GameState.DIFFICULTIES[GameState.difficulty]
	item_limit = 2 if training_battle else int(balance.item_limit)
	for id in GameState.BATTLE_ITEMS:
		stock[id] = GameState.BATTLE_ITEMS[id].initial if training_battle else GameState.item_counts[id]
	$Cells.position = grid_position
	$Cells.scale = grid_scale
	$Units.position = grid_position
	$Units.scale = grid_scale
	if use_template_layout:
		normalize_from_templates()

	var hitbox := RectangleShape2D.new()
	hitbox.size = cell_hitbox_size
	var half := cell_visual_size / 2.0
	var polygon := PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	for cell in cells:
		cell.hitbox.shape = hitbox
		cell.tile.polygon = polygon
		cells_by_position[cell.grid_position] = cell
		cell.obstacle = cell.grid_position in obstacles
		cell.set_highlighted(false)

	for unit in units:
		if not training_battle and unit.team == "enemy":
			unit.max_hp = maxi(1, roundi(unit.max_hp * balance.hp))
			unit.attack = maxi(1, roundi(unit.attack * balance.attack))
		unit.hp = unit.max_hp
		unit.update_stats_label()
		if unit.reinforcement:
			reserves.append(unit)
			unit.hide()
			var gate := get_cell_by_position(unit.cell)
			gate.entry = true
			gate.set_highlighted(false)
		align_unit_to_cell(unit)

	retry_button.pressed.connect(_on_retry_pressed)
	map_button.pressed.connect(_on_map_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	surrender_button.pressed.connect(_on_surrender_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	items_button.pressed.connect(_on_items_pressed)
	for id in item_buttons:
		var button: Button = item_buttons[id]
		button.pressed.connect(select_item.bind(id))
		setup_item_button(button, id)
	setup_action_bar()
	instruction_label.add_theme_font_size_override("font_size", 17)
	instruction_label.add_theme_constant_override("outline_size", 4)
	instruction_label.add_theme_color_override("font_outline_color", Color("#171820"))
	instruction_label.position += Vector2(12, 10)
	setup_item_cancel_button()
	result_layer.visible = false
	result_back_button.visible = false
	menu_layer.visible = true
	menu_panel.visible = false
	items_drawer.visible = false
	update_item_buttons()
	update_turn_label()

func align_unit_to_cell(unit: Area2D) -> void:
	var cell := get_cell_by_position(unit.cell)
	if cell != null:
		unit.global_position = cell.global_position

func get_cell_by_position(cell_position: Vector2i) -> Area2D:
	return cells_by_position.get(cell_position)

func neighbor_positions(origin: Vector2i) -> Array[Vector2i]:
	if neighbors_by_position.has(origin):
		return neighbors_by_position[origin]
	var neighbors: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := origin + Vector2i(dx, dy)
			if pos != origin and cells_by_position.has(pos):
				neighbors.append(pos)
	neighbors_by_position[origin] = neighbors
	return neighbors

func normalize_from_templates() -> void:
	var cell_template := $Cells.get_node_or_null("Cell07") as Area2D
	var unit_template := $Units.get_node_or_null("Player1") as Area2D
	if cell_template == null or unit_template == null:
		return

	for cell in cells:
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

	for unit in units:
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

func board_open() -> bool:
	return current_turn == Turn.PLAYER and not battle_finished and not menu_panel.visible and not items_drawer.visible

func _unhandled_input(event: InputEvent) -> void:
	if not board_open() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
	else:
		return
	for cell in cells:
		var shape: CollisionShape2D = cell.hitbox
		var local: Vector2 = shape.get_global_transform_with_canvas().affine_inverse() * event.position
		var bounds: Vector2 = shape.shape.size
		if Rect2(-bounds / 2.0, bounds).has_point(local):
			var occupant := unit_at(cell.grid_position)
			if occupant:
				_on_unit_pressed(occupant)
			else:
				_on_cell_pressed(cell)
			get_viewport().set_input_as_handled()
			return

func unit_at(position_on_grid: Vector2i) -> Area2D:
	for unit in units:
		if unit.visible and unit.hp > 0 and unit.cell == position_on_grid:
			return unit
	return null

func _on_unit_pressed(unit: Area2D) -> void:
	if not board_open() or not unit.visible or unit.hp <= 0 or mode == "retreat":
		return
	if selecting_item != "":
		if unit in attack_targets:
			use_item(unit)
		return
	if unit in attack_targets:
		resolve_attack(unit)
		return
	hide_inspected_stats()
	unit.set_stats_visible(true)
	inspected_unit = unit
	if unit.team == "player" and unit.actions_left > 0:
		select_unit(unit)
	elif unit.team == "enemy":
		instruction_label.text = "Противник · %d/%d HP · атака %d" % [unit.hp, unit.max_hp, unit.attack]

func _on_cell_pressed(cell: Area2D) -> void:
	if not board_open() or selected_unit == null or cell not in highlighted_cells:
		return
	var actor := selected_unit
	place_unit(actor, cell.grid_position)
	if mode == "retreat":
		finish_action(actor)
	else:
		actor.stepped = true
		select_unit(actor)

func place_unit(unit: Area2D, destination: Vector2i) -> void:
	unit.cell = destination
	align_unit_to_cell(unit)
	if defender.guarding and not is_adjacent(defender.cell, striker.cell):
		defender.guarding = false

func free_neighbors(unit: Area2D) -> Array[Area2D]:
	var result: Array[Area2D] = []
	for pos in neighbor_positions(unit.cell):
		var cell: Area2D = cells_by_position[pos]
		if not cell.obstacle and not cell.entry and unit_at(pos) == null:
			result.append(cell)
	return result

func show_cells(available_cells: Array[Area2D]) -> void:
	for cell in available_cells:
		cell.set_highlighted(true)
		highlighted_cells.append(cell)

func show_target(unit: Area2D) -> void:
	unit.set_attackable(true)
	attack_targets.append(unit)

func select_unit(unit: Area2D, command := "attack") -> void:
	clear_selection()
	selected_unit = unit
	mode = command
	unit.set_selected(true)
	var neighbors := free_neighbors(unit)
	if mode == "attack" and not unit.stepped:
		show_cells(neighbors)
	var can_attack := false
	var can_push := false
	var can_withdraw := false
	for enemy in units:
		if enemy.team != "enemy" or not enemy.visible or not is_adjacent(unit.cell, enemy.cell):
			continue
		can_attack = true
		var destination: Vector2i = enemy.cell + (enemy.cell - unit.cell)
		var beyond := get_cell_by_position(destination)
		var pushable: bool = unit_at(destination) == null and (beyond == null or not beyond.entry)
		var escape: bool = not neighbors.is_empty() or attack_damage(unit, enemy, true) >= enemy.hp
		can_push = can_push or pushable
		can_withdraw = can_withdraw or escape
		if (mode != "push" or pushable) and (mode != "withdraw" or escape):
			show_target(enemy)
	var partners_close: bool = striker.hp > 0 and defender.hp > 0 and is_adjacent(defender.cell, striker.cell)
	for key in commands:
		var button: Button = commands[key]
		button.visible = (key != "withdraw" or unit == striker) and (key not in ["cover", "swap"] or unit == defender)
		match key:
			"cover", "swap": button.disabled = not partners_close
			"withdraw": button.disabled = not can_withdraw
			"push": button.disabled = not can_push
			"attack": button.disabled = not can_attack and mode == "attack"
		button.set_pressed_no_signal(key == mode)
	action_bar.show()
	var role := "Защитник" if unit == defender else "Напарник"
	match mode:
		"push": instruction_label.text = "Выбери врага для толчка · столкновение 12 урона"
		"withdraw": instruction_label.text = "Выбери врага для удара с отходом"
		_: instruction_label.text = role + (" · выбери действие" if unit.stepped else " · шаг или действие")

func on_command(command: String) -> void:
	if not board_open() or selected_unit == null or mode == "retreat":
		return
	if commands[command].disabled or not commands[command].visible:
		return
	var actor := selected_unit
	match command:
		"cover":
			defender.guarding = true
		"swap":
			var old: Vector2i = defender.cell
			defender.cell = striker.cell
			striker.cell = old
			align_unit_to_cell(defender)
			align_unit_to_cell(striker)
		"wait": pass
		_:
			select_unit(actor, command)
			return
	finish_action(actor)

func attack_damage(actor: Area2D, target: Area2D, withdrawing: bool) -> int:
	var damage: int = roundi(actor.attack * 0.75) if withdrawing else actor.attack
	if actor == striker and target.marked and not finisher_used:
		damage += 8
	return damage

func resolve_attack(target: Area2D) -> void:
	var actor := selected_unit
	var withdrawing := mode == "withdraw"
	if mode == "push":
		var destination: Vector2i = target.cell + (target.cell - actor.cell)
		var cell := get_cell_by_position(destination)
		if unit_at(destination) or (cell and cell.entry):
			return
		if cell == null or cell.obstacle:
			deal_damage(target, 12)
		else:
			place_unit(target, destination)
	else:
		var damage := attack_damage(actor, target, withdrawing)
		if actor == striker and target.marked and not finisher_used:
			finisher_used = true
			for enemy in units:
				enemy.marked = false
		deal_damage(target, damage)
	if actor == defender and not finisher_used:
		target.marked = true
	check_battle_result()
	if battle_finished:
		return
	if withdrawing:
		clear_selection()
		selected_unit = actor
		mode = "retreat"
		show_cells(free_neighbors(actor))
		if not highlighted_cells.is_empty():
			actor.set_selected(true)
			items_button.disabled = true
			instruction_label.text = "Выбери клетку для отхода"
			return
	finish_action(actor)

func deal_damage(target: Area2D, damage: int) -> void:
	target.show_damage(damage)
	target.take_damage(damage)

func clear_selection() -> void:
	for cell in highlighted_cells:
		cell.set_highlighted(false)
	for unit in attack_targets:
		unit.set_attackable(false)
	highlighted_cells.clear()
	attack_targets.clear()
	if selected_unit:
		selected_unit.set_selected(false)
	selected_unit = null
	mode = "attack"
	action_bar.hide()

func hide_inspected_stats() -> void:
	if inspected_unit:
		inspected_unit.set_stats_visible(false)
		inspected_unit = null

func finish_action(unit: Area2D) -> void:
	unit.stepped = true
	unit.actions_left -= 1
	player_action_count += 1
	clear_selection()
	hide_inspected_stats()
	items_button.disabled = false
	update_turn_label()
	if remaining_actions() == 0:
		end_player_turn()

func remaining_actions() -> int:
	var count := 0
	for hero in [defender, striker]:
		if hero.hp > 0:
			count += hero.actions_left
	return count

func end_player_turn() -> void:
	current_turn = Turn.AI
	menu_button.disabled = true
	items_button.disabled = true
	clear_selection()
	update_turn_label()
	await get_tree().create_timer(0.45, false).timeout
	for enemy in units:
		if battle_finished:
			return
		if enemy.team == "enemy" and enemy.visible:
			await run_enemy_turn(enemy)
	if battle_finished:
		return
	if reserves.size() > 0 and living_enemies() <= reinforcement_threshold:
		for enemy in reserves:
			var gate := get_cell_by_position(enemy.cell)
			gate.entry = false
			gate.set_highlighted(false)
			enemy.show()
		reserves.clear()
	current_turn = Turn.PLAYER
	player_action_count = 0
	menu_button.disabled = false
	items_used_this_turn = 0
	items_button.disabled = false
	finisher_used = false
	for unit in units:
		unit.marked = false
		unit.guarding = false
		unit.stepped = false
		unit.used_adrenaline = false
		unit.actions_left = 1
		if unit.strength_turns > 0:
			unit.strength_turns -= 1
			if unit.strength_turns == 0:
				unit.attack -= 12
				unit.update_stats_label()
	update_item_buttons()
	update_turn_label()

func run_enemy_turn(enemy: Area2D) -> void:
	if enemy.stunned_turns > 0:
		enemy.stunned_turns -= 1
		instruction_label.text = "%s оглушён и пропускает ход" % enemy.name
		await get_tree().create_timer(0.45, false).timeout
		return

	var adjacent_target := choose_adjacent_player(enemy)
	if adjacent_target != null:
		enemy.set_attackable(true)
		await get_tree().create_timer(0.25, false).timeout
		enemy.set_attackable(false)
		if battle_finished:
			return
		var damage: int = enemy.attack
		if adjacent_target == striker and defender.guarding and defender.hp > 0 and is_adjacent(defender.cell, striker.cell):
			adjacent_target = defender
			damage = ceili(damage / 2.0)
			defender.guarding = false
		deal_damage(adjacent_target, damage)
		instruction_label.text = "Противник наносит %d урона" % damage
		check_battle_result()
		await get_tree().create_timer(0.45, false).timeout
		return

	var target := choose_best_player_target(enemy)
	if target == null:
		return

	var next_cell := choose_best_move_cell(enemy, target)
	if next_cell != null:
		enemy.cell = next_cell.grid_position
		enemy.global_position = next_cell.global_position
		instruction_label.text = "%s перемещается" % enemy.name
	await get_tree().create_timer(0.35, false).timeout

func choose_adjacent_player(enemy: Area2D) -> Area2D:
	var best_target: Area2D
	var best_score := INF
	for unit in units:
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
	for unit in units:
		if unit.team != "player" or not unit.visible or unit.hp <= 0:
			continue
		var score := get_target_score(enemy, unit)
		if score < best_score:
			best_score = score
			best_target = unit
	return best_target

func get_target_score(enemy: Area2D, target: Area2D) -> float:
	var distance: int = abs(enemy.cell.x - target.cell.x) + abs(enemy.cell.y - target.cell.y)
	if not training_battle and GameState.difficulty == 0:
		return distance
	var protected_ally: bool = target == striker and defender.guarding and defender.hp > 0
	if not training_battle and GameState.difficulty == 2 and not protected_ally and is_adjacent(enemy.cell, target.cell) and target.hp <= enemy.attack:
		return -1000.0 + target.hp
	return distance * 10.0 + target.hp * 0.25 - target.attack * 0.5

func choose_best_move_cell(enemy: Area2D, target: Area2D) -> Area2D:
	var destination: Vector2i = target.cell
	var frontier: Array[Vector2i] = []
	var first_step := {enemy.cell: null}
	for cell in cells:
		if cell.obstacle or cell.entry:
			first_step[cell.grid_position] = null
	for unit in units:
		if unit.visible and unit.hp > 0:
			first_step[unit.cell] = null

	for pos in neighbor_positions(enemy.cell):
		if not first_step.has(pos):
			frontier.append(pos)
			first_step[pos] = cells_by_position[pos]
	# Each BFS layer stays grouped by first step. Sorting these choices
	# once preserves the preferred move among equally short routes.
	frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(destination) < b.distance_squared_to(destination))
	var index := 0
	while index < frontier.size():
		var origin := frontier[index]
		index += 1
		var step: Area2D = first_step[origin]
		if is_adjacent(origin, destination):
			return step
		for pos in neighbor_positions(origin):
			if not first_step.has(pos):
				first_step[pos] = step
				frontier.append(pos)
	return null

func is_adjacent(first: Vector2i, second: Vector2i) -> bool:
	return first != second \
		and abs(first.x - second.x) <= 1 \
		and abs(first.y - second.y) <= 1

func living_enemies() -> int:
	var count := 0
	for unit in units:
		if unit.team == "enemy" and unit.visible and unit.hp > 0:
			count += 1
	return count

func check_battle_result() -> void:
	if battle_finished:
		return
	if defender.hp <= 0 and striker.hp <= 0:
		show_defeat()
	elif reserves.is_empty() and living_enemies() == 0:
		show_victory()

func show_victory() -> void:
	battle_finished = true
	menu_layer.hide()
	GameSettings.vibrate_result(true)
	clear_selection()
	if training_battle:
		GameState.complete_level(GameState.TRAINING_LEVEL)
		result_title.text = "ОБУЧЕНИЕ ПРОЙДЕНО"
	else:
		GameState.item_counts.assign(stock)
		var coins := GameState.complete_current_level()
		result_title.text = "ПОБЕДА!"
		if coins > 0:
			result_title.text += "\n+%d монет" % coins
	retry_button.visible = false
	map_button.visible = true
	result_back_button.visible = false
	result_layer.visible = true

func show_defeat() -> void:
	battle_finished = true
	menu_layer.hide()
	GameSettings.vibrate_result(false)
	result_title.text = "ПОРАЖЕНИЕ"
	retry_button.visible = true
	map_button.visible = true
	result_back_button.visible = defender.hp > 0 or striker.hp > 0
	result_layer.visible = true

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://Global_Map.tscn")

func _on_result_back_pressed() -> void:
	battle_finished = false
	result_layer.hide()
	menu_layer.show()
	menu_panel.show()

func _on_menu_pressed() -> void:
	if not battle_finished and current_turn == Turn.PLAYER:
		if mode != "retreat":
			cancel_item_selection()
		items_drawer.hide()
		menu_panel.show()

func _on_surrender_pressed() -> void:
	menu_panel.visible = false
	show_defeat()

func _on_settings_pressed() -> void:
	menu_layer.add_child(preload("res://settings.tscn").instantiate())

func _on_continue_pressed() -> void:
	menu_panel.visible = false

func _on_items_pressed() -> void:
	if battle_finished or current_turn != Turn.PLAYER or mode == "retreat":
		return
	cancel_item_selection()
	menu_panel.hide()
	items_drawer.visible = not items_drawer.visible
	update_item_buttons()

func can_use_item() -> bool:
	return current_turn == Turn.PLAYER and not battle_finished and items_used_this_turn < item_limit and mode != "retreat"

func select_item(id: String) -> void:
	if not can_use_item() or stock[id] <= 0:
		return
	clear_selection()
	for unit in units:
		if not unit.visible or unit.hp <= 0:
			continue
		if (unit.team == "enemy") != (id in ["bomb", "brick"]):
			continue
		if (id == "medkit" and unit.hp >= unit.max_hp) or (id == "adrenaline" and unit.used_adrenaline) or (id == "brick" and unit.stunned_turns > 0):
			continue
		show_target(unit)
	if attack_targets.is_empty():
		items_title.text = "Нет подходящей цели"
		return
	selecting_item = id
	items_drawer.hide()
	cancel_item_button.show()
	instruction_label.text = "Выбери цель · " + GameState.BATTLE_ITEMS[id].name

func use_item(target: Area2D) -> void:
	var id := selecting_item
	if not can_use_item() or target not in attack_targets:
		return
	stock[id] -= 1
	items_used_this_turn += 1
	cancel_item_selection()
	match id:
		"medkit":
			var healed := mini(50, target.max_hp - target.hp)
			target.hp += healed
			target.show_effect(healed, "heal")
		"strength":
			if target.strength_turns == 0:
				target.attack += 12
			target.strength_turns = 2
			target.show_effect(12, "attack")
		"bomb":
			deal_damage(target, 30)
			for enemy in units:
				if enemy.team == "enemy" and enemy.visible and is_adjacent(target.cell, enemy.cell):
					deal_damage(enemy, 15)
		"brick":
			target.stunned_turns = 1
		"adrenaline":
			target.actions_left += 1
			target.used_adrenaline = true
	target.update_stats_label()
	update_item_buttons()
	update_turn_label()
	check_battle_result()

func cancel_item_selection() -> void:
	selecting_item = ""
	cancel_item_button.hide()
	clear_selection()

func _on_cancel_item_pressed() -> void:
	cancel_item_selection()
	items_drawer.show()
	update_item_buttons()

func update_item_buttons() -> void:
	items_title.text = "Предметы · %d/%d" % [items_used_this_turn, item_limit]
	var descriptions := {"medkit": "+50 HP", "strength": "+12 ATK на 2 хода", "bomb": "30/15 урона", "brick": "Оглушение", "adrenaline": "+1 действие"}
	for id in item_buttons:
		var button: Button = item_buttons[id]
		button.get_node("ItemDescription").text = "%s  ×%d" % [descriptions[id], stock[id]]
		button.disabled = stock[id] <= 0 or not can_use_item()

func setup_action_bar() -> void:
	menu_layer.add_child(action_bar)
	action_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_bar.offset_bottom = -6
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#20232ded")
	normal.set_content_margin_all(10)
	normal.set_corner_radius_all(4)
	normal.border_width_bottom = 3
	normal.border_color = Color("#646679")
	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = Color("#51452e")
	active.border_color = Color("#f1c971")
	var inactive := normal.duplicate() as StyleBoxFlat
	inactive.bg_color = Color("#22252bb0")
	inactive.border_color = Color("#424451")
	var hints := {
		"attack": "Обычный удар по соседней цели.",
		"push": "Толкни врага на клетку. Столкновение со стеной наносит 12 урона.",
		"cover": "Первый удар по соседнему напарнику примет защитник за половину урона.",
		"swap": "Поменяйся местами с напарником. Он сохранит своё действие.",
		"withdraw": "Нанеси 75% урона и выбери соседнюю клетку для отхода.",
		"wait": "Заверши текущее действие этого героя.",
	}
	var titles := {"attack": "Атака", "push": "Толчок", "cover": "Прикрыть", "swap": "Рокировка", "withdraw": "Удар с отходом", "wait": "Завершить"}
	for key in titles:
		var button := Button.new()
		button.text = titles[key]
		button.tooltip_text = hints[key]
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", active)
		button.add_theme_stylebox_override("pressed", active)
		button.add_theme_stylebox_override("disabled", inactive)
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = key in ["attack", "push", "withdraw"]
		button.pressed.connect(on_command.bind(key))
		action_bar.add_child(button)
		commands[key] = button
	action_bar.hide()

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
	if current_turn == Turn.AI:
		instruction_label.text = "Ход противника"
		return
	instruction_label.text = "Твой ход · действий %d" % remaining_actions()
	if not reserves.is_empty():
		instruction_label.text += "\nЯнтарные клетки · вход подкрепления"
