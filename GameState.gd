extends Node

signal money_changed(amount: int)

const SAVE_PATH := "user://savegame.json"
const TRAINING_LEVEL := "training"
const FIRST_BATTLE_LEVEL := "Level 3"

const BATTLE_ITEMS := {
	"medkit": {
		"name": "Снюс",
		"description": "Восстанавливает выбранному союзнику до 50 HP. При полном здоровье применить нельзя.",
		"icon": preload("res://textures/items/Снюс.png"),
		"initial": 2,
	},
	"strength": {
		"name": "Медавуха",
		"description": "Даёт выбранному союзнику +15 к атаке на два хода. Повторное применение обновляет срок действия бонуса.",
		"icon": preload("res://textures/items/Медавуха.png"),
		"initial": 2,
	},
	"bomb": {
		"name": "Карсар",
		"description": "Наносит 30 урона выбранному врагу и по 15 урона врагам на соседних клетках, включая диагональные.",
		"icon": preload("res://textures/items/Карсар.png"),
		"initial": 1,
	},
	"brick": {
		"name": "Кирпич",
		"description": "Оглушает одного выбранного врага. Этот враг пропускает свой ближайший ход.",
		"icon": preload("res://textures/items/Кирпич.png"),
		"initial": 2,
	},
	"adrenaline": {
		"name": "Энергетик Адреналин",
		"description": "Даёт союзнику два дополнительных действия в текущем ходу. Применяется до его первого действия. Следующий ход этот союзник пропускает.",
		"icon": preload("res://textures/items/Энергетик Адреналин.png"),
		"initial": 2,
	},
}

var item_counts: Dictionary[String, int] = {}
var money := 0:
	set(value):
		if money != value:
			money = value
			money_changed.emit(money)

const LEVEL_ORDER: Array[String] = [
	"Level 2 ( no fight )",
	"Level 3",
	"Level 4 ( no fight )",
	"Level 5",
	"Level 6 ( no fight )",
	"Level 7",
	"Level 8",
	"Level 9 ( no fight )",
]

# Имя текущего узла на карте, где находится игрок.
var current_level_name: String = LEVEL_ORDER[0]

# Список пройденных уровней (по именам узлов на карте)
var completed_levels: Array[String] = []
# Список открытых уровней
var unlocked_levels: Array[String] = [LEVEL_ORDER[0]]

var has_saved_progress: bool = false

func _ready() -> void:
	for item_id in BATTLE_ITEMS:
		item_counts[item_id] = BATTLE_ITEMS[item_id].initial
	load_game()

func consume_battle_item(item_id: String) -> void:
	item_counts[item_id] -= 1
	save_game()

func buy_battle_item(item_id: String, price: int) -> bool:
	if price < 0 or money < price or not item_counts.has(item_id):
		return false

	item_counts[item_id] += 1
	money -= price
	save_game()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

func is_level_unlocked(level_name_on_map: String) -> bool:
	if level_name_on_map == FIRST_BATTLE_LEVEL and TRAINING_LEVEL not in completed_levels:
		return false
	return level_name_on_map in unlocked_levels

func select_level(level_name_on_map: String) -> bool:
	if not is_level_unlocked(level_name_on_map):
		return false

	current_level_name = level_name_on_map
	save_game()
	return true

func complete_current_level() -> void:
	var current_index := LEVEL_ORDER.find(current_level_name)
	var next_level_name := ""
	if current_index >= 0 and current_index + 1 < LEVEL_ORDER.size():
		next_level_name = LEVEL_ORDER[current_index + 1]

	complete_level(current_level_name, next_level_name)

# Вызывай эту функцию в конце любого уровня при победе
func complete_level(level_name_on_map: String, next_level_name_on_map: String = "") -> void:
	if not level_name_on_map in completed_levels:
		completed_levels.append(level_name_on_map)
	
	if next_level_name_on_map != "":
		if not next_level_name_on_map in unlocked_levels:
			unlocked_levels.append(next_level_name_on_map)

	save_game()

func save_game() -> void:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Не удалось открыть файл сохранения: %s" % SAVE_PATH)
		return

	var save_data := {
		"current_level_name": current_level_name,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"item_counts": item_counts,
		"money": money,
	}
	save_file.store_string(JSON.stringify(save_data))
	save_file.close()
	has_saved_progress = true

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Не удалось открыть файл сохранения: %s" % SAVE_PATH)
		return

	var save_data = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if not save_data is Dictionary:
		push_error("Файл сохранения повреждён: ожидался JSON-объект")
		return

	var saved_money: Variant = save_data.get("money", 0)
	if saved_money is int or saved_money is float:
		money = maxi(int(saved_money), 0)

	var saved_items: Variant = save_data.get("item_counts", {})
	if saved_items is Dictionary:
		for item_id in BATTLE_ITEMS:
			var count: Variant = saved_items.get(item_id)
			if count is int or count is float:
				item_counts[item_id] = maxi(int(count), 0)

	var saved_current_level: Variant = save_data.get("current_level_name", LEVEL_ORDER[0])
	if saved_current_level is String and saved_current_level in LEVEL_ORDER:
		current_level_name = saved_current_level

	var saved_completed_levels: Variant = save_data.get("completed_levels", [])
	if saved_completed_levels is Array:
		completed_levels.clear()
		for level_name in saved_completed_levels:
			if level_name is String and (level_name in LEVEL_ORDER or level_name == TRAINING_LEVEL):
				completed_levels.append(level_name)

	var saved_unlocked_levels: Variant = save_data.get("unlocked_levels", [LEVEL_ORDER[0]])
	if saved_unlocked_levels is Array:
		unlocked_levels.clear()
		for level_name in saved_unlocked_levels:
			if level_name is String and level_name in LEVEL_ORDER:
				unlocked_levels.append(level_name)
		if unlocked_levels.is_empty():
			unlocked_levels.append(LEVEL_ORDER[0])

	has_saved_progress = true
