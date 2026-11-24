extends Area2D

@onready var touch_button: TouchScreenButton = $TouchScreenButton

# Путь к сцене, в которую нужно перекинуть игрока
var next_scene_path: String = "res://corridor 1.tscn"

var is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	touch_button.pressed.connect(_on_button_pressed)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		is_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		is_player_inside = false



func _on_button_pressed() -> void:
	if is_player_inside:
		if next_scene_path != "":
			get_tree().change_scene_to_file(next_scene_path)


func _on_touch_screen_button_pressed() -> void:
	pass
