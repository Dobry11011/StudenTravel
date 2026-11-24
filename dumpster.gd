extends "res://interaction_area.gd"

@export var dumpster_id := ""

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
	var reward: Dictionary = GameState.search_dumpster(dumpster_id)
	match reward.type:
		"money":
			result_label.text = "+%d монет" % reward.amount
		"item":
			var item: Dictionary = GameState.BATTLE_ITEMS[reward.item_id]
			result_label.text = "Предмет: %s" % item.name
	result_label.show()
	_mark_searched()


func _mark_searched() -> void:
	monitoring = false
	monitorable = false
	for body in get_overlapping_bodies():
		if body.has_method("remove_interaction_target"):
			body.remove_interaction_target(self)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.75))

