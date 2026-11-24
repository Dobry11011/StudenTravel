extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_pressed() -> void:
	if GameState.has_saved_progress:
		get_tree().change_scene_to_file("res://Global_Map.tscn")
	else:
		get_tree().change_scene_to_file("res://Level 0.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_info_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
