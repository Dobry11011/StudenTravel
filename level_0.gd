extends Node2D

const WAYPOINTS: Array[Vector2] = [Vector2(578, 209), Vector2(876, 209)]
const WAYPOINT_RADIUS := 14.0

@onready var player: CharacterBody2D = $Player
@onready var player_collider: CollisionShape2D = $Player/CollisionShape2D
@onready var hint: Label = $Tutorial/HUD/Hint
@onready var marker: Node2D = $RouteMarker
@onready var exit_zone: Area2D = $Exit

var waypoint_index := 0
var exit_nearby := false


func _ready() -> void:
	_update_tutorial()


func _physics_process(_delta: float) -> void:
	if waypoint_index < WAYPOINTS.size():
		if player_collider.global_position.distance_to(WAYPOINTS[waypoint_index]) <= WAYPOINT_RADIUS:
			waypoint_index += 1
			_update_tutorial()


func _update_tutorial() -> void:
	marker.visible = not exit_nearby
	if exit_nearby:
		hint.text = "Нажми «Взаимодействовать» справа внизу, чтобы открыть дверь."
	elif waypoint_index == 0:
		marker.position = WAYPOINTS[0]
		hint.text = "Потяни джойстик слева внизу. Дойди до метки."
	else:
		marker.position = WAYPOINTS[1] if waypoint_index == 1 else exit_zone.position
		hint.text = "Следуй за меткой к двери."


func _on_exit_body_entered(body: Node2D) -> void:
	if body == player:
		exit_nearby = true
		waypoint_index = WAYPOINTS.size()
		_update_tutorial()


func _on_exit_body_exited(body: Node2D) -> void:
	if body == player:
		exit_nearby = false
		_update_tutorial()
