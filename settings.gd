extends Control

func _on_back_pressed() -> void:
	get_tree().set_meta("open_battle_menu", true)
	var return_scene := "res://battle_arena.tscn"
	if get_tree().has_meta("settings_return_scene"):
		return_scene = get_tree().get_meta("settings_return_scene")
		get_tree().remove_meta("settings_return_scene")
	get_tree().change_scene_to_file(return_scene)
