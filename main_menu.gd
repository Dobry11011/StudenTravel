extends Control

const DEVELOPER_URL := "https://taplink.cc/dobrygyga"

var chooser: ColorRect
var chooser_content: VBoxContainer
var selected_slot := 1

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$ColorRect.resized.connect(_resize_rain)
	_resize_rain()
	_build_chooser()

func _resize_rain() -> void:
	$ColorRect/Rain.scale = $ColorRect.size

func _build_chooser() -> void:
	chooser = ColorRect.new()
	chooser.color = Color(0.015, 0.02, 0.035, 0.94)
	chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser.visible = false
	add_child(chooser)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser.add_child(center)
	chooser_content = VBoxContainer.new()
	chooser_content.custom_minimum_size.x = 520
	chooser_content.add_theme_constant_override("separation", 14)
	center.add_child(chooser_content)

func _show_slots() -> void:
	_clear_content()
	_add_title("Выберите сохранение")
	for slot in range(1, 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		chooser_content.add_child(row)
		var select_button := Button.new()
		select_button.custom_minimum_size = Vector2(370, 68)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has_save: bool = GameState.slot_exists(slot)
		if has_save:
			select_button.text = "Ячейка %d  ·  Продолжить" % slot
		else:
			select_button.text = "Ячейка %d  ·  Новая игра" % slot
		select_button.pressed.connect(_on_slot_selected.bind(slot))
		row.add_child(select_button)
		if has_save:
			var delete_button := Button.new()
			delete_button.text = "Удалить"
			delete_button.custom_minimum_size = Vector2(130, 68)
			delete_button.pressed.connect(_confirm_slot_deletion.bind(slot))
			row.add_child(delete_button)
	_add_back_button(false)
	chooser.show()

func _confirm_slot_deletion(slot: int) -> void:
	_clear_content()
	_add_title("Удалить сохранение из ячейки %d?" % slot)
	var confirm := Button.new()
	confirm.text = "Удалить сохранение"
	confirm.custom_minimum_size.y = 62
	confirm.pressed.connect(_delete_slot.bind(slot))
	chooser_content.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.pressed.connect(_show_slots)
	chooser_content.add_child(cancel)

func _delete_slot(slot: int) -> void:
	if GameState.delete_slot(slot):
		_show_slots()

func _on_slot_selected(slot: int) -> void:
	selected_slot = slot
	if GameState.slot_exists(slot):
		GameState.load_slot(slot)
		get_tree().change_scene_to_file("res://Global_Map.tscn")
		return
	_clear_content()
	_add_title("Выберите сложность")
	var names := ["Под пивом  ·  Лёгкая", "На подумать  ·  Средняя", "Отчисление  ·  Сложная"]
	for index in range(names.size()):
		var button := Button.new()
		button.text = names[index]
		button.custom_minimum_size.y = 62
		button.pressed.connect(_on_difficulty_selected.bind(index))
		chooser_content.add_child(button)
	_add_back_button(true)

func _on_difficulty_selected(value: int) -> void:
	GameState.start_new_game(selected_slot, value)
	get_tree().change_scene_to_file("res://Level 0.tscn")

func _clear_content() -> void:
	for child in chooser_content.get_children():
		child.queue_free()

func _add_title(value: String) -> void:
	var title := Label.new()
	title.text = value
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	chooser_content.add_child(title)

func _add_back_button(back_to_slots: bool) -> void:
	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(_show_slots if back_to_slots else _hide_chooser)
	chooser_content.add_child(back)

func _hide_chooser() -> void:
	chooser.hide()

func _on_start_pressed() -> void:
	_show_slots()

func _on_settings_pressed() -> void:
	add_child(preload("res://settings.tscn").instantiate())

func _on_info_pressed() -> void:
	_show_developer_info()
	var result := OS.shell_open(DEVELOPER_URL)
	if result != OK:
		push_warning("Не удалось открыть ссылку разработчика: %s" % error_string(result))

func _show_developer_info() -> void:
	_clear_content()
	_add_title("О разработчиках")
	var credit := Label.new()
	credit.text = "В разработке участвовал Исаев Артем"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chooser_content.add_child(credit)
	_add_back_button(false)
	chooser.show()
	chooser_content.get_child(-1).grab_focus()
