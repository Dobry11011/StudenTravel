extends Node2D

const PLAYER_SPEED := 46.0
const DODGE_SPEED := 210.0
const PLAYER_MIN_Y := 220.0
const PLAYER_MAX_Y := 370.0
const FINISH_X := 1085.0
const CAR_SPAWN_X := 1230.0
const TRAFFIC_SPEED := [280.0, 310.0, 350.0]
const OUTER_LANES := [266.0, 397.0]
const CENTER_LANE := 331.0
const MIN_REACTION_TIME := 0.85
const MAP_SCENE := "res://Global_Map.tscn"

class TrafficCar extends Node2D:
	var car_color := Color("d9574f")
	var speed: float

	func _draw() -> void:
		# The broad silhouette keeps the car readable over the dark bridge art.
		var body := PackedVector2Array([
			Vector2(-56, -13), Vector2(-44, -22), Vector2(28, -22),
			Vector2(48, -14), Vector2(56, -7), Vector2(56, 14),
			Vector2(43, 20), Vector2(-45, 20), Vector2(-56, 12),
		])
		draw_colored_polygon(body, car_color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-35, -17), Vector2(-24, -17), Vector2(-18, -4), Vector2(-39, -4),
		]), Color("9fd0d0"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12, -17), Vector2(21, -17), Vector2(34, -5), Vector2(-10, -5),
		]), Color("9fd0d0"))
		draw_rect(Rect2(-39, 11, 22, 5), Color("252525"))
		draw_rect(Rect2(22, 11, 22, 5), Color("252525"))
		draw_circle(Vector2(-42, 3), 5, Color("ffd56a"))
		draw_circle(Vector2(47, 3), 4, Color("ff756b"))


@onready var player: CharacterBody2D = $Player
@onready var player_sprite: AnimatedSprite2D = $Player/AnimatedSprite2D
@onready var up_button: Button = $DodgeControls/Arrows/Up
@onready var down_button: Button = $DodgeControls/Arrows/Down

var _cars: Array[TrafficCar] = []
var cars_spawned := 0
var _spawn_timer := 0.8
var _game_over := false
var _finished := false
var _progress_label: Label
var _displayed_percent := 0
var _result_layer: CanvasLayer


func _ready() -> void:
	$Player/CanvasLayer.hide()
	$Player/CanvasLayer/Joystick.set_process_input(false)
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player_sprite.play("walk_side")
	player_sprite.flip_h = false
	_build_hud()


func _process(delta: float) -> void:
	var vertical_input := Input.get_axis("ui_up", "ui_down")
	if up_button.button_pressed or down_button.button_pressed:
		vertical_input = float(down_button.button_pressed) - float(up_button.button_pressed)

	player.position.x = minf(player.position.x + PLAYER_SPEED * delta, FINISH_X)
	player.position.y = clampf(player.position.y + vertical_input * DODGE_SPEED * delta, PLAYER_MIN_Y, PLAYER_MAX_Y)
	var percent := int((player.position.x / FINISH_X) * 100.0)
	if percent != _displayed_percent:
		_displayed_percent = percent
		_progress_label.text = "ДО ФИНИША: %d%%" % percent

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_car()
		_spawn_timer = GameState.DIFFICULTIES[GameState.difficulty].traffic_interval

	_update_cars(delta)
	if player.position.x >= FINISH_X:
		_show_result(true)


func _spawn_car() -> void:
	var speed: float = TRAFFIC_SPEED[GameState.difficulty]
	# Leave enough time after the car becomes visible to change lanes.
	if (minf(CAR_SPAWN_X, get_viewport_rect().size.x) - player.position.x - 67.0) / (speed + PLAYER_SPEED) < MIN_REACTION_TIME:
		return
	cars_spawned += 1
	var lane: float = OUTER_LANES.pick_random()
	if GameState.difficulty > 0 and cars_spawned % 3 == 0:
		lane = CENTER_LANE
	var car := TrafficCar.new()
	car.speed = speed
	car.car_color = [Color("d9574f"), Color("4c9fd6"), Color("e1a941"), Color("72aa72")].pick_random()
	car.position = Vector2(CAR_SPAWN_X, lane)
	add_child(car)
	_cars.append(car)


func _update_cars(delta: float) -> void:
	# Match each car against the player's body near the character's feet.
	var player_center := player.position + Vector2(-16.0, 29.0)
	for index in range(_cars.size() - 1, -1, -1):
		var car := _cars[index]
		car.position.x -= car.speed * delta
		var separation := player_center - car.position
		if absf(separation.x) < 67.0 and absf(separation.y) < 38.0:
			_show_result(false)
			return

		if car.position.x < -100.0:
			car.queue_free()
			_cars.remove_at(index)


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	_progress_label = Label.new()
	_progress_label.position = Vector2(24, 18)
	_progress_label.add_theme_font_size_override("font_size", 24)
	_progress_label.add_theme_color_override("font_color", Color.WHITE)
	_progress_label.text = "ДО ФИНИША: 0%"
	hud.add_child(_with_shadow(_progress_label))

	var help := Label.new()
	help.position = Vector2(24, 52)
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", Color("fff0c5"))
	help.text = "Удерживай ↑ или ↓, чтобы уклониться"
	hud.add_child(_with_shadow(help))


func _with_shadow(label: Label) -> Label:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _show_result(won: bool) -> void:
	if _game_over or _finished:
		return
	_game_over = not won
	_finished = won
	$DodgeControls.hide()
	set_process(false)
	GameSettings.vibrate_result(won)
	player_sprite.stop()
	if won:
		GameState.complete_current_level()

	_result_layer = CanvasLayer.new()
	_result_layer.layer = 20
	add_child(_result_layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	_result_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 250)
	center.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 16)
	panel.add_child(contents)

	var title := Label.new()
	title.text = "Мост пройден!" if won else "Ты попал под машину!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	contents.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Отлично, путь свободен." if won else "Попробуй ещё раз и уворачивайся от машин."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(subtitle)

	var action := Button.new()
	action.custom_minimum_size.y = 48
	action.text = "Продолжить" if won else "Заново"
	action.pressed.connect(_on_result_action_pressed)
	contents.add_child(action)

	var map_button := Button.new()
	map_button.custom_minimum_size.y = 42
	map_button.text = "На карту"
	map_button.pressed.connect(_on_map_pressed)
	contents.add_child(map_button)


func _on_result_action_pressed() -> void:
	if _finished:
		get_tree().change_scene_to_file(MAP_SCENE)
	else:
		get_tree().reload_current_scene()


func _on_map_pressed() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
