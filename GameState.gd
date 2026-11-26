extends Node

signal money_changed(amount: int)

const SAVE_PATH := "user://savegame.json"
var selected_slot := 1
var difficulty := 1
const DIFFICULTIES := [
	{"name": "Под пивом", "hp": 0.70, "attack": 0.65, "item_limit": 2, "traffic_interval": 2.0, "items": {"medkit": 2, "strength": 1, "bomb": 0, "brick": 1, "adrenaline": 0}},
	{"name": "На подумать", "hp": 1.0, "attack": 1.0, "item_limit": 2, "traffic_interval": 1.55, "items": {"medkit": 1, "strength": 0, "bomb": 0, "brick": 1, "adrenaline": 0}},
	{"name": "Отчисление", "hp": 1.12, "attack": 1.20, "item_limit": 1, "traffic_interval": 1.25, "items": {"medkit": 1, "strength": 0, "bomb": 0, "brick": 0, "adrenaline": 0}},
]
const TRAINING_LEVEL := "training"
const FIRST_BATTLE_LEVEL := "Level 3"
const VICTORY_COINS := {"Level 3": 40, "Level 5": 50, "Level 7": 60, "Level 8": 70}

const BATTLE_ITEMS := {
	"medkit": {
		"name": "Снюс",
		"price": 35,
		"description": "Восстанавливает выбранному союзнику до 50 HP. При полном здоровье применить нельзя.",
		"icon": preload("res://textures/items/Снюс.png"),
		"initial": 2,
	},
	"strength": {
		"name": "Медавуха",
		"price": 45,
		"description": "Даёт выбранному союзнику +12 к атаке на два хода. Повторное применение обновляет срок действия бонуса.",
		"icon": preload("res://textures/items/Медавуха.png"),
		"initial": 2,
	},
	"bomb": {
		"name": "Карсар",
		"price": 55,
		"description": "Наносит 30 урона выбранному врагу и по 15 урона врагам на соседних клетках, включая диагональные.",
		"icon": preload("res://textures/items/Карсар.png"),
		"initial": 1,
	},
	"brick": {
		"name": "Кирпич",
		"price": 50,
		"description": "Оглушает одного выбранного врага. Этот враг пропускает свой ближайший ход.",
		"icon": preload("res://textures/items/Кирпич.png"),
		"initial": 2,
	},
	"adrenaline": {
		"name": "Энергетик Адреналин",
		"price": 65,
		"description": "Даёт союзнику одно дополнительное действие в этом раунде. Шаг не восстанавливается. Один раз на союзника за раунд.",
		"icon": preload("res://textures/items/Энергетик Адреналин.png"),
		"initial": 2,
	},
}

var item_counts: Dictionary[String, int] = {}
var searched_dumpsters: Array[String] = []
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
	load_slot(1)

func slot_path(slot: int) -> String:
	return "user://savegame_slot_%d.json" % slot

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or (slot == 1 and FileAccess.file_exists(SAVE_PATH))

func delete_slot(slot: int) -> bool:
	if slot < 1 or slot > 3 or not slot_exists(slot):
		return false
	var paths := [slot_path(slot)]
	if slot == 1:
		paths.append(SAVE_PATH)
	var removed := false
	for path in paths:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error("Не удалось удалить сохранение: %s" % path)
				return false
			removed = true
	if removed and slot == selected_slot:
		has_saved_progress = false
	return removed

func start_new_game(slot: int, difficulty_id: int) -> void:
	selected_slot = slot
	difficulty = clampi(difficulty_id, 0, DIFFICULTIES.size() - 1)
	current_level_name = LEVEL_ORDER[0]
	completed_levels.clear()
	unlocked_levels = [LEVEL_ORDER[0]]
	money = 0
	searched_dumpsters.clear()
	item_counts.assign(DIFFICULTIES[difficulty].items)
	has_saved_progress = true
	save_game()

func load_slot(slot: int) -> void:
	selected_slot = clampi(slot, 1, 3)
	current_level_name = LEVEL_ORDER[0]
	completed_levels.clear()
	unlocked_levels = [LEVEL_ORDER[0]]
	money = 0
	searched_dumpsters.clear()
	difficulty = 1
	item_counts.assign(DIFFICULTIES[difficulty].items)
	has_saved_progress = false
	var path := slot_path(selected_slot)
	if selected_slot == 1 and not FileAccess.file_exists(path) and FileAccess.file_exists(SAVE_PATH):
		path = SAVE_PATH
	load_game(path)

func buy_battle_item(item_id: String) -> bool:
	if not BATTLE_ITEMS.has(item_id) or not item_counts.has(item_id):
		return false
	var price: int = BATTLE_ITEMS[item_id].price
	if money < price:
		return false

	item_counts[item_id] += 1
	money -= price
	save_game()
	return true

func search_dumpster(dumpster_id: String, coin_range: Vector2i) -> int:
	if dumpster_id.is_empty() or dumpster_id in searched_dumpsters:
		return 0
	searched_dumpsters.append(dumpster_id)
	var coins := randi_range(coin_range.x, coin_range.y)
	money += coins
	save_game()
	return coins

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

func complete_current_level() -> int:
	var current_index := LEVEL_ORDER.find(current_level_name)
	var next_level_name := ""
	if current_index >= 0 and current_index + 1 < LEVEL_ORDER.size():
		next_level_name = LEVEL_ORDER[current_index + 1]

	return complete_level(current_level_name, next_level_name)

# Вызывай эту функцию в конце любого уровня при победе
func complete_level(level_name_on_map: String, next_level_name_on_map: String = "") -> int:
	var coins := 0
	if not level_name_on_map in completed_levels:
		completed_levels.append(level_name_on_map)
		coins = VICTORY_COINS.get(level_name_on_map, 0)
		money += coins
	
	if next_level_name_on_map != "":
		if not next_level_name_on_map in unlocked_levels:
			unlocked_levels.append(next_level_name_on_map)

	save_game()
	return coins

func save_game() -> void:
	if not has_saved_progress:
		return
	var save_file := FileAccess.open(slot_path(selected_slot), FileAccess.WRITE)
	if save_file == null:
		push_error("Не удалось открыть файл сохранения: %s" % SAVE_PATH)
		return

	var save_data := {
		"current_level_name": current_level_name,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"item_counts": item_counts,
		"money": money,
		"searched_dumpsters": searched_dumpsters,
		"difficulty": difficulty,
	}
	save_file.store_string(JSON.stringify(save_data))
	save_file.close()
	has_saved_progress = true

func load_game(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	var save_file := FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		push_error("Не удалось открыть файл сохранения: %s" % SAVE_PATH)
		return

	var save_data = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if not save_data is Dictionary:
		push_error("Файл сохранения повреждён: ожидался JSON-объект")
		return
	difficulty = clampi(int(save_data.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	item_counts.assign(DIFFICULTIES[difficulty].items)

	var saved_money: Variant = save_data.get("money", 0)
	if saved_money is int or saved_money is float:
		money = maxi(int(saved_money), 0)
	var saved_dumpsters: Variant = save_data.get("searched_dumpsters", [])
	if saved_dumpsters is Array:
		searched_dumpsters.clear()
		for dumpster_id in saved_dumpsters:
			if dumpster_id is String and not dumpster_id in searched_dumpsters:
				searched_dumpsters.append(dumpster_id)

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
