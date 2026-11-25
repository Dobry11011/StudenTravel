extends "res://interaction_area.gd"

@export var dumpster_id := ""
@export var coin_range := Vector2i(18, 22)

@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	super._ready()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.hide()
	if dumpster_id in GameState.searched_dumpsters:
		result_label.text = "Пусто"
		result_label.show()
		_mark_searched()


func interact() -> void:
	if not monitoring:
		return
	var coins := GameState.search_dumpster(dumpster_id, coin_range)
	result_label.text = "Монеты +%d" % coins if coins > 0 else "Пусто"
	result_label.show()
	_mark_searched()


func _mark_searched() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("remove_interaction_target"):
			body.remove_interaction_target(self)
	monitoring = false
	monitorable = false
	result_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.75))
