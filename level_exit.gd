extends "res://interaction_area.gd"

@export_file("*.tscn") var next_scene := ""
@export var complete_level := false


func interact() -> void:
	if complete_level:
		GameState.complete_current_level()
	get_tree().change_scene_to_file(next_scene)
