extends Control

@onready var base: Sprite2D = $Base
@onready var tip: Sprite2D = $Base/Tip

@export var max_distance := 100.0

var touch_id : int = -1
var pos_vector := Vector2.ZERO 

func _ready() -> void:
	base.position = size / 2
	tip.position = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_node_ready():
		reset_joystick()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			var local_pos = event.position - global_position
			if local_pos.length() < max_distance * 1.5:
				touch_id = event.index
				update_joystick(event.position)
		elif not event.pressed and event.index == touch_id:
			reset_joystick()

	if event is InputEventScreenDrag and event.index == touch_id:
		update_joystick(event.position)

func update_joystick(touch_pos: Vector2) -> void:
	var center = base.global_position
	var vector = touch_pos - center
	
	if vector.length() > max_distance:
		vector = vector.normalized() * max_distance
		
	tip.global_position = center + vector
	pos_vector = vector / max_distance

func reset_joystick() -> void:
	touch_id = -1
	pos_vector = Vector2.ZERO
	tip.position = Vector2.ZERO
