extends ColorRect

signal free_practice_requested

const PAGES := {
	"Поле и ход": "Нажми на бойца, чтобы увидеть HP и ATK. HP — оставшееся здоровье, ATK — сила обычного удара. Когда HP падает до нуля, боец выбывает.\n\nКаждый живой союзник за раунд может шагнуть на одну свободную соседнюю клетку и выполнить действие. Диагонали тоже считаются. Шаг можно пропустить. Голубые клетки показывают, куда пойти, красная подсветка — кого можно атаковать.\n\nВыбирай героев в любом порядке. «Завершить» тратит текущее действие героя. Когда действия команды закончатся, каждый враг передвинется или ударит. В новом раунде шаги и действия восстановятся.",
	"Способности": "У защитника жёлтая полоска, 125 HP и 20 атаки. «Прикрыть» действует, пока союзники рядом. Защитник принимает первый удар по напарнику за половину урона. «Рокировка» меняет соседних героев местами и сохраняет действие напарника.\n\nУ напарника голубая полоска, 85 HP и 32 атаки. «Удар с отходом» наносит 75% урона, затем ты выбираешь свободную соседнюю клетку. Если защитник в этом раунде ударил или толкнул цель, напарник получает +8 к первому удару по отмеченной цели.\n\nОба героя умеют толкать. На свободной клетке враг просто сдвинется. У препятствия или края поля он останется на месте и получит 12 урона.",
	"Предметы": "",
	"Волны и сложность": "Победи всех врагов, включая подкрепления. Если оба союзника выбыли, бой проигран. Янтарные стрелки заранее показывают вход подкреплений. После их появления первой действует твоя команда.\n\nНа уровнях 3, 5, 7 и 8 предстоит победить 2, 3, 4 и 5 противников. Одновременно на поле бывает до трёх врагов.\n\nНа лёгкой враги слабее и идут к ближайшему герою. На средней они учитывают расстояние, здоровье и силу цели. На сложной враги сильнее и стараются добить уязвимого героя. Оба союзника получают ход на каждой сложности.",
	"Карта и локации": "На карте нажми на открытую локацию. Чтобы попасть на уровень 3, пройди уровень 2 и победи в тренировке. В обучение можно вернуться с карты.\n\nВ мирной локации веди героя экранным джойстиком. Подойди к персонажу, двери или контейнеру. Когда появится кнопка взаимодействия, нажми её. В контейнере можно найти монеты или предмет. Каждый контейнер обыскивается один раз.\n\nВ инвентаре видны твои вещи и их эффекты. В магазине на карте выбери предмет, посмотри цену и нажми «Купить». Покупка добавится в запас для следующих боёв.",
	"Мост": "На уровне 6 герой сам бежит к финишу. Смотри, по какой полосе едет ближайшая машина. Уводи героя вверх или вниз джойстиком либо стрелками ↑ и ↓.\n\nСтолкновение завершает попытку. Нажми «Заново», чтобы попробовать ещё раз. На средней и сложной машины иногда едут по центру, а на сложной ещё и появляются чаще. Добеги до конца моста, чтобы продолжить путь.",
}

@onready var topics: VBoxContainer = %Topics
@onready var page_title: Label = %PageTitle
@onready var page_text: Label = %PageText
@onready var scroll: ScrollContainer = %PageScroll
@onready var independent: Button = %Independent
var paused_before := false
var topic_buttons := ButtonGroup.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	page_text.add_theme_font_override("font", ThemeDB.fallback_font)
	for title: String in PAGES:
		var button := Button.new()
		button.text = title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		button.add_theme_font_override("font", ThemeDB.fallback_font)
		button.add_theme_font_size_override("font_size", 19)
		button.toggle_mode = true
		button.button_group = topic_buttons
		button.pressed.connect(_show_page.bind(title))
		topics.add_child(button)
	%CloseBook.pressed.connect(close_book)
	independent.pressed.connect(_practice)
	topics.get_child(0).button_pressed = true
	_show_page("Поле и ход")

func _show_page(title: String) -> void:
	page_title.text = title
	if title == "Предметы":
		var lines := PackedStringArray(["Открой «Предметы», выбери вещь, затем подсвеченную цель. «Отмена» возвращает к выбору."])
		for id in GameState.BATTLE_ITEMS:
			var item: Dictionary = GameState.BATTLE_ITEMS[id]
			lines.append("%s. %s" % [item.name, item.description])
		lines.append("В тренировке можно использовать две вещи за раунд. В кампании лимит — две на лёгкой и средней сложности, одна на сложной. Учебные предметы выдаются отдельно. В кампании расход сохраняется при победе, после поражения или сдачи запас возвращается.")
		page_text.text = "\n\n".join(lines)
	else:
		page_text.text = PAGES[title]
	scroll.scroll_vertical = 0

func open_book(guided: bool) -> void:
	if visible:
		return
	paused_before = get_tree().paused
	independent.visible = guided
	show()
	get_tree().paused = true
	%CloseBook.grab_focus()

func close_book() -> void:
	hide()
	get_tree().paused = paused_before
	$"../Lesson/GuideButton".grab_focus()

func _practice() -> void:
	close_book()
	free_practice_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_book()

func _exit_tree() -> void:
	if visible:
		get_tree().paused = paused_before
