extends Area2D

signal cell_pressed(cell: Area2D)

@export var grid_position := Vector2i.ZERO
@onready var tile: Polygon2D = $Tile

var normal_color := Color(1.0, 1.0, 1.0, 0.0)
var highlighted_color := Color(0.25, 0.75, 1.0, 0.35)

func _ready() -> void:
	$TouchScreenButton.pressed.connect(_on_touch_screen_button_pressed)
	tile.color = normal_color

func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		cell_pressed.emit(self)
	elif event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		cell_pressed.emit(self)

func set_highlighted(value: bool) -> void:
	tile.color = highlighted_color if value else normal_color

func _on_touch_screen_button_pressed() -> void:
	cell_pressed.emit(self)
