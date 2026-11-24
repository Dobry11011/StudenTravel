extends "res://interaction_area.gd"

@export var phrases: Array[String] = []

@onready var dialogue_label: Label = $Label

var speak_on_approach := false
var display_version := 0


func _on_interaction_body_entered(body: Node2D) -> void:
	if speak_on_approach:
		if body.has_method("add_interaction_target"):
			interact()
	else:
		super._on_interaction_body_entered(body)


func _on_interaction_body_exited(body: Node2D) -> void:
	if not speak_on_approach:
		super._on_interaction_body_exited(body)
	if body.has_method("remove_interaction_target"):
		dialogue_label.hide()
		display_version += 1


func interact() -> void:
	if phrases.is_empty():
		return
	dialogue_label.text = phrases.pick_random()
	dialogue_label.show()
	display_version += 1
	var version := display_version
	await get_tree().create_timer(2.5, false).timeout
	if display_version == version:
		dialogue_label.hide()
