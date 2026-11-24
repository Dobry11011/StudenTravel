extends Control

var selected_item_id := ""
var buy_animation: Tween
var leaving := false

@onready var catalog: VBoxContainer = $Layout/Frame/Catalog/Items
@onready var details: PanelContainer = $Layout/Frame/Details
@onready var details_scroll: ScrollContainer = $Layout/Frame/Details/Scroll
@onready var item_title: Label = $Layout/Frame/Details/Scroll/Content/Title
@onready var item_icon: TextureRect = $Layout/Frame/Details/Scroll/Content/Icon
@onready var item_description: Label = $Layout/Frame/Details/Scroll/Content/Description
@onready var price: Label = $Layout/Frame/Price
@onready var status: Label = $Layout/Frame/Status
@onready var buy_button: Button = $Layout/Frame/BuyButton
@onready var buy_feedback: ColorRect = $Layout/Frame/BuyButton/Feedback
@onready var exit_feedback: ColorRect = $Layout/Frame/ExitButton/Feedback


func _ready() -> void:
	var font := ThemeDB.fallback_font
	for label in [item_title, item_description, price, status]:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 16)
	_update_status()

	var selection := ButtonGroup.new()
	for item_id in GameState.BATTLE_ITEMS:
		var item: Dictionary = GameState.BATTLE_ITEMS[item_id]
		var button := Button.new()
		button.text = "%s   ·   %d" % [item.name, item.price]
		button.tooltip_text = button.text
		button.icon = item.icon
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size.y = 43
		button.add_theme_constant_override("icon_max_width", 32)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 16)
		button.toggle_mode = true
		button.button_group = selection
		button.pressed.connect(_show_item.bind(item_id))
		catalog.add_child(button)
	$Layout/Frame/CloseButton.grab_focus()


func _show_item(item_id: String) -> void:
	selected_item_id = item_id
	var item: Dictionary = GameState.BATTLE_ITEMS[item_id]
	item_title.text = item.name
	item_icon.texture = item.icon
	item_description.text = item.description
	details.show()
	details_scroll.scroll_vertical = 0
	price.text = "Цена: %d" % item.price
	price.show()
	buy_button.disabled = false
	_update_status()


func _on_buy_pressed() -> void:
	if selected_item_id.is_empty() or leaving:
		return

	if buy_animation != null:
		buy_animation.kill()
	buy_animation = _play_press(buy_feedback)
	if GameState.buy_battle_item(selected_item_id):
		_update_status("Предмет куплен")
	else:
		_update_status("Не хватает денег")


func _update_status(message: String = "") -> void:
	status.text = "Баланс: %d" % GameState.money
	if not message.is_empty():
		status.text += "\n" + message


func _play_press(feedback: ColorRect) -> Tween:
	feedback.modulate.a = 1.0
	var animation := create_tween()
	animation.tween_property(feedback, "modulate:a", 0.0, 0.16)
	return animation


func _on_exit_pressed() -> void:
	if leaving:
		return
	leaving = true
	await _play_press(exit_feedback).finished
	_return_to_map()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_map()


func _return_to_map() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://Global_Map.tscn")
	else:
		queue_free()
