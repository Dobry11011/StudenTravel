extends Node

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "settings"

var volume_percent := 100
var vibration_enabled := true
var joke_enabled := false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		volume_percent = clampi(int(config.get_value(SECTION, "volume_percent", 100)), 0, 100)
		vibration_enabled = bool(config.get_value(SECTION, "vibration_enabled", true))
		joke_enabled = bool(config.get_value(SECTION, "joke_enabled", false))
	apply_volume()

func apply_volume() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, volume_percent == 0)
	if volume_percent > 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(volume_percent / 100.0))

func vibrate(duration_ms: int = 60) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func vibrate_result(won: bool) -> void:
	vibrate(180 if won else 320)

func save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "volume_percent", volume_percent)
	config.set_value(SECTION, "vibration_enabled", vibration_enabled)
	config.set_value(SECTION, "joke_enabled", joke_enabled)
	var result := config.save(CONFIG_PATH)
	if result != OK:
		push_warning("Не удалось сохранить настройки: %s" % error_string(result))
