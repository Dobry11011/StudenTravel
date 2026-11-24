extends Node2D

@export var player: CharacterBody2D
@export var exit_zone: Area2D
@export var waypoints: PackedVector2Array
@export var waypoint_hints: PackedStringArray
@export var waypoint_radius := 14.0
@export var approach_hint := "Следуй за меткой к двери."
@export var exit_hint := "Нажми «Взаимодействовать» справа внизу, чтобы открыть дверь."

@onready var player_collider: CollisionShape2D = player.get_node("CollisionShape2D")
@onready var hint: Label = $Overlay/HUD/Hint
@onready var marker: Node2D = $RouteMarker

var waypoint_index := 0
var exit_nearby := false


func _ready() -> void:
	exit_zone.body_entered.connect(_on_exit_body_entered)
	exit_zone.body_exited.connect(_on_exit_body_exited)
	_update_tutorial()


func _physics_process(_delta: float) -> void:
	if waypoint_index >= waypoints.size():
		return
	if player_collider.global_position.distance_to(waypoints[waypoint_index]) <= waypoint_radius:
		waypoint_index += 1
		_update_tutorial()


func _update_tutorial() -> void:
	marker.visible = not exit_nearby
	if exit_nearby:
		hint.text = exit_hint
	elif waypoint_index < waypoints.size():
		marker.global_position = waypoints[waypoint_index]
		hint.text = waypoint_hints[waypoint_index] if waypoint_index < waypoint_hints.size() else approach_hint
	else:
		marker.global_position = exit_zone.interaction_position()
		hint.text = approach_hint


func _on_exit_body_entered(body: Node2D) -> void:
	if body == player:
		exit_nearby = true
		waypoint_index = waypoints.size()
		_update_tutorial()


func _on_exit_body_exited(body: Node2D) -> void:
	if body == player:
		exit_nearby = false
		_update_tutorial()
