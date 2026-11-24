extends Area2D

@onready var interaction_shape := find_children("*", "CollisionShape2D", false).front() as CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_interaction_body_entered)
	body_exited.connect(_on_interaction_body_exited)


func _on_interaction_body_entered(body: Node2D) -> void:
	if body.has_method("add_interaction_target"):
		body.add_interaction_target(self)


func _on_interaction_body_exited(body: Node2D) -> void:
	if body.has_method("remove_interaction_target"):
		body.remove_interaction_target(self)


func interaction_position() -> Vector2:
	return interaction_shape.global_position
