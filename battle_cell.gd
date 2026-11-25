extends Area2D


@export var grid_position := Vector2i.ZERO
@onready var tile: Polygon2D = $Tile

var normal_color := Color(1.0, 1.0, 1.0, 0.0)
var highlighted_color := Color(0.25, 0.75, 1.0, 0.35)

var obstacle := false
var entry := false

func _ready() -> void:
	$TouchScreenButton.hide()
	input_pickable = false
	tile.show_behind_parent = true
	tile.color = normal_color

func set_highlighted(value: bool) -> void:
	queue_redraw()
	if obstacle:
		tile.color = Color("#21263291")
	elif entry:
		tile.color = Color("#d796303f")
	else:
		tile.color = highlighted_color if value else normal_color

func _draw() -> void:
	if obstacle:
		# Concrete roadblock with feet and a striped reflective face.
		draw_rect(Rect2(-24, 9, 48, 7), Color("#1c1c25"))
		draw_rect(Rect2(-21, 4, 8, 10), Color("#878386"))
		draw_rect(Rect2(13, 4, 8, 10), Color("#878386"))
		draw_rect(Rect2(-24, -13, 48, 19), Color("#42424d"))
		draw_rect(Rect2(-24, -14, 48, 3), Color("#c4b9a0"))
		for x in [-19, -5, 9]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, -9), Vector2(x + 8, -9), Vector2(x + 3, 1), Vector2(x - 5, 1)
			]), Color("#d1a347"))
	elif entry:
		draw_rect(Rect2(-27, -26, 54, 52), Color("#e8aa4b"), false, 2)
		var direction := 1 if grid_position.x == 0 else -1
		for x in [-7, 5]:
			draw_polyline(PackedVector2Array([
				Vector2(x, -9), Vector2(x + direction * 7, 0), Vector2(x, 9)
			]), Color("#ffd382"), 3)
