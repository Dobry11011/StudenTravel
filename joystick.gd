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
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_node_ready():
				reset_joystick()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_id == -1:
			var local_pos := make_canvas_position_local(event.position)
			var bounds := base.get_rect()
			var base_pos := base.make_canvas_position_local(event.position)
			var normalized_pos := (base_pos - bounds.get_center()) / (bounds.size * 0.5)
			if normalized_pos.length_squared() <= 1.0:
				touch_id = event.index
				update_joystick(local_pos)
		elif (not event.pressed or event.canceled) and event.index == touch_id:
			reset_joystick()

	elif event is InputEventScreenDrag and event.index == touch_id:
		update_joystick(make_canvas_position_local(event.position))

func update_joystick(touch_pos: Vector2) -> void:
	var vector := (touch_pos - base.position).limit_length(max_distance)

	tip.global_position = get_global_transform() * (base.position + vector)
	pos_vector = vector / max_distance

func reset_joystick() -> void:
	touch_id = -1
	pos_vector = Vector2.ZERO
	tip.position = Vector2.ZERO
