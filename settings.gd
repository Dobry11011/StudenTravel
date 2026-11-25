extends Control

var was_paused: bool

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var vibration_toggle: CheckButton = %VibrationToggle
@onready var joke_toggle: CheckButton = %JokeToggle

func _ready() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true
	volume_slider.set_value_no_signal(GameSettings.volume_percent)
	volume_value.text = "%d%%" % GameSettings.volume_percent
	vibration_toggle.set_pressed_no_signal(GameSettings.vibration_enabled)
	joke_toggle.set_pressed_no_signal(GameSettings.joke_enabled)
	_update_joke_text()
	volume_slider.grab_focus()

func _exit_tree() -> void:
	get_tree().paused = was_paused

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _on_volume_changed(value: float) -> void:
	GameSettings.volume_percent = roundi(value)
	GameSettings.apply_volume()
	volume_value.text = "%d%%" % GameSettings.volume_percent
	GameSettings.save()

func _on_vibration_toggled(enabled: bool) -> void:
	GameSettings.vibration_enabled = enabled
	GameSettings.vibrate()
	GameSettings.save()

func _on_joke_toggled(enabled: bool) -> void:
	GameSettings.joke_enabled = enabled
	_update_joke_text()
	GameSettings.save()

func _update_joke_text() -> void:
	joke_toggle.text = "Лох ли ты?  %s" % ("Да" if GameSettings.joke_enabled else "Нет")

func _on_back_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://main_menu.tscn")
	else:
		queue_free()
