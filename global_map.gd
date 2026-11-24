extends Node2D

const MARKER_TEXTURES := {
	"locked": preload("res://textures/globalMap/Закрыто.png"),
	"available": preload("res://textures/globalMap/Место.png"),
	"player": preload("res://textures/globalMap/Игрок.png"),
}

const LEVEL_SCENES := {
	"Level 2 ( no fight )": "res://Level 2 (street).tscn",
	"training": "res://training.tscn",
	"Level 3": "res://level_3.tscn",
	"Level 4 ( no fight )": "res://level 4 (public_garden).tscn",
	"Level 5": "res://level_5.tscn",
	"Level 6 ( no fight )": "res://level 6 (bridge).tscn",
	"Level 7": "res://level_7.tscn",
	"Level 8": "res://level_8.tscn",
	"Level 9 ( no fight )": "res://level 9 (hostel).tscn",
}

const LEVEL_LABELS := {
	"Level 2 ( no fight )": "2",
	"training": "Обучение",
	"Level 3": "3",
	"Level 4 ( no fight )": "4",
	"Level 5": "5",
	"Level 6 ( no fight )": "6",
	"Level 7": "7",
	"Level 8": "8",
	"Level 9 ( no fight )": "9",
}

@onready var levels: Node2D = $Levels
@onready var unlock_hint: Label = $ShopLayer/UnlockHint

func _ready() -> void:
	for level_node in levels.get_children():
		if level_node is Area2D:
			level_node.input_pickable = true
			level_node.input_event.connect(_on_level_input_event.bind(level_node))

			var marker := Sprite2D.new()
			marker.name = "StatusMarker"
			marker.z_index = 10
			marker.scale = Vector2(0.5, 0.5)
			level_node.add_child(marker)

			var level_label := Label.new()
			level_label.name = "LevelLabel"
			level_label.text = LEVEL_LABELS.get(level_node.name, level_node.name)
			level_label.position = Vector2(-50, -55)
			level_label.size = Vector2(100, 30)
			level_label.z_index = 11
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_node.add_child(level_label)

	update_markers()

func _on_main_menu_button_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_shop_button_pressed() -> void:
	get_tree().change_scene_to_file("res://shop.tscn")

func update_markers() -> void:
	for level_node in levels.get_children():
		if not level_node is Area2D:
			continue

		var marker := level_node.get_node_or_null("StatusMarker") as Sprite2D
		if marker == null:
			continue

		if level_node.name == GameState.TRAINING_LEVEL:
			marker.texture = MARKER_TEXTURES["available"]
		elif not GameState.is_level_unlocked(level_node.name):
			marker.texture = MARKER_TEXTURES["locked"]
		elif level_node.name == GameState.current_level_name:
			marker.texture = MARKER_TEXTURES["player"]
		else:
			marker.texture = MARKER_TEXTURES["available"]

func _on_level_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	level_node: Area2D
) -> void:
	if not (
		(event is InputEventMouseButton and event.pressed) or
		(event is InputEventScreenTouch and event.pressed)
	):
		return

	if level_node.name == GameState.TRAINING_LEVEL:
		get_tree().change_scene_to_file(LEVEL_SCENES["training"])
	elif GameState.select_level(level_node.name):
		get_tree().change_scene_to_file(LEVEL_SCENES[level_node.name])
	elif level_node.name == GameState.FIRST_BATTLE_LEVEL:
		if GameState.TRAINING_LEVEL not in GameState.completed_levels:
			unlock_hint.text = "Чтобы открыть уровень 3, выиграй бой в «Обучении»."
		else:
			unlock_hint.text = "Чтобы открыть уровень 3, пройди уровень 2."
		unlock_hint.show()
