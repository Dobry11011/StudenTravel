extends "res://battle_arena.gd"

# Each goal is an actual unit, arena command or board coordinate. The same goal
# drives the highlighted target, input validation and progress through the lesson.
const LESSONS := [
	{"title": "Шаг и атака", "steps": [
		{"goal": "Enemy1", "prompt": "Нажми на врага в белой рамке.", "why": "Победи всех врагов. Их полоски здоровья красные. HP — очки здоровья, ATK — урон обычного удара."},
		{"hero": "Player1", "goal": Vector2i(2, 4), "prompt": "Шагни на голубую клетку в рамке.", "why": "Каждый герой может шагнуть на одну свободную клетку, в том числе по диагонали, а затем действовать."},
		{"hero": "Player1", "goal": "Enemy1", "prompt": "Теперь нажми на врага рядом с защитником.", "why": "Обычная атака уже выбрана. Защитник снимет 20 HP. После удара ходить этим героем уже нельзя."},
	]},
	{"title": "Удар вдвоём и отход", "steps": [
		{"hero": "Player2", "mode": "withdraw", "goal": "Enemy1", "prompt": "Ударь того же врага.", "why": "После защитника на враге горит метка. Раз за раунд напарник получает +8 урона по такой цели. Удар с отходом здесь нанесёт 24 + 8."},
		{"hero": "Player2", "goal": Vector2i(3, 5), "prompt": "Выбери клетку в рамке для отхода.", "why": "Обычный удар напарника наносит 32 урона. Удар с отходом наносит 75% и позволяет сразу отступить на соседнюю клетку."},
	]},
	{"title": "Прикрытие и смена хода", "steps": [
		{"hero": "Player1", "goal": "cover", "prompt": "Нажми «Прикрыть».", "why": "Пока герои рядом, первый удар по напарнику примет защитник. У врага 10 атаки, поэтому защитник потеряет только 5 HP."},
		{"hero": "Player2", "goal": "wait", "prompt": "Нажми «Завершить» и проследи за полосками здоровья.", "why": "Напарник останется рядом. Когда у команды закончатся действия, каждый враг сможет шагнуть или ударить. Затем снова ходишь ты."},
	]},
	{"title": "Помощь и оглушение", "steps": [
		{"item": "medkit", "goal": "Player1", "prompt": "Нажми на раненого защитника.", "why": "Защитник принял удар за друга. Снюс восстанавливает до 50 HP. Число над героем покажет, сколько здоровья вернулось."},
		{"item": "brick", "goal": "Enemy1", "prompt": "Выбери противника для оглушения.", "why": "Кирпич заставит врага пропустить ближайший ход. Предметы расходуют отдельный лимит. Оба героя ещё могут действовать."},
		{"hero": "Player1", "goal": "swap", "prompt": "Нажми «Рокировка».", "why": "Герои поменяются местами. Для этого они должны стоять рядом. Действие потратит только защитник."},
		{"hero": "Player2", "mode": "push", "goal": "Enemy1", "prompt": "Толкни врага в полосатое ограждение.", "why": "Толчок сдвигает врага на клетку от героя. У стены или края поля враг остаётся на месте и получает 12 урона."},
	]},
	{"title": "Усиление и лишнее действие", "steps": [
		{"item": "strength", "goal": "Player2", "prompt": "Дай Медавуху напарнику.", "why": "На два хода его атака вырастет с 32 до 44. Ещё одна Медавуха обновит срок усиления."},
		{"item": "adrenaline", "goal": "Player2", "prompt": "Дай Адреналин тому же герою.", "why": "Напарник получит ещё одно действие в этом раунде. Дополнительного шага предмет не даёт."},
		{"hero": "Player2", "goal": "Enemy1", "prompt": "Нанеси обычный удар усиленным напарником.", "why": "Напарник уже рядом с целью. Можно сразу атаковать и сохранить позицию."},
		{"hero": "Player2", "goal": "Enemy1", "prompt": "Ударь ещё раз, чтобы победить первого врага.", "why": "Адреналин позволяет действовать этим же героем второй раз."},
		{"hero": "Player1", "goal": "wait", "prompt": "Нажми «Завершить», чтобы встретить подкрепление.", "why": "Янтарные стрелки на краю поля отмечают клетки входа. После появления новой группы первыми ходят союзники."},
	]},
	{"title": "Подкрепление и бой без подсказок", "steps": [
		{"item": "bomb", "goal": "Enemy2", "prompt": "Брось Карсар во врага в рамке. Следи за обеими полосками.", "why": "Выбранная цель получит 30 урона, а соседние враги, включая стоящих по диагонали, — по 15. Союзники в безопасности."},
	]},
]

@onready var lesson: Panel = $"../Tutorial/Lesson"
@onready var heading: Label = lesson.get_node("Heading")
@onready var prompt: Label = lesson.get_node("Prompt")
@onready var explanation: Label = lesson.get_node("Explanation")
@onready var pointer: Panel = $"../Tutorial/Pointer"
@onready var guide = $"../Tutorial/Guide"

var chapter := 0
var step_index := 0
var reminder_time := 0.0
var displayed_turn := Turn.PLAYER
var displayed_instruction := ""

func _ready() -> void:
	super()
	instruction_label.hide()
	for label in [prompt, explanation]:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
	lesson.get_node("GuideButton").pressed.connect(_open_guide)
	guide.free_practice_requested.connect(_start_free_practice)
	for panel in [menu_panel, items_drawer, cancel_item_button, result_layer, guide]:
		panel.visibility_changed.connect(_refresh, CONNECT_DEFERRED)
	# Containers can reposition a highlighted button after the input callback.
	for button in commands.values() + item_buttons.values() + [items_button]:
		button.item_rect_changed.connect(_refresh, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_refresh, CONNECT_DEFERRED)
	_refresh()

func _process(delta: float) -> void:
	if reminder_time > 0.0:
		reminder_time = maxf(0.0, reminder_time - delta)
		if reminder_time == 0.0:
			_refresh()
	if displayed_turn != current_turn or displayed_instruction != instruction_label.text:
		_refresh()

func _guided() -> bool:
	return chapter < LESSONS.size()

func _step() -> Dictionary:
	return LESSONS[chapter].steps[step_index]

func _goal(step: Dictionary) -> CanvasItem:
	if step.goal is Vector2i:
		return get_cell_by_position(step.goal)
	if commands.has(step.goal):
		return commands[step.goal]
	return $Units.get_node(step.goal)

func _expected(step: Dictionary) -> CanvasItem:
	if step.has("item"):
		if selecting_item == step.item:
			return _goal(step)
		return item_buttons[step.item] if items_drawer.visible else items_button
	if step.has("hero"):
		var hero := $Units.get_node(step.hero)
		if selected_unit != hero:
			return hero
		if step.has("mode") and mode != step.mode:
			return commands[step.mode]
	return _goal(step)

func _refresh() -> void:
	displayed_turn = current_turn
	displayed_instruction = instruction_label.text
	set_process(reminder_time > 0.0 or current_turn == Turn.AI or not _guided())
	lesson.visible = not (battle_finished or menu_panel.visible or guide.visible)
	pointer.visible = lesson.visible and _guided() and current_turn == Turn.PLAYER
	if not lesson.visible:
		return
	if _guided():
		heading.text = "Урок %d/%d · %s" % [chapter + 1, LESSONS.size(), LESSONS[chapter].title]
	else:
		heading.text = "Самостоятельный бой"
	if current_turn == Turn.AI:
		prompt.text = "Ход противника. Посмотри, что он сделает."
		explanation.text = instruction_label.text.replace("Enemy1", "Противник").replace("Enemy2", "Противник").replace("Enemy3", "Противник")
		return
	if not _guided():
		prompt.text = instruction_label.text
		explanation.text = "Победи всех врагов, чтобы закончить обучение. Правила можно посмотреть в справке."
		return
	var step := _step()
	var target := _expected(step)
	if target == _goal(step):
		prompt.text = step.prompt
	elif target == items_button:
		prompt.text = "Открой «Предметы» справа."
	elif items_drawer.visible:
		prompt.text = "Выбери «%s» в списке." % GameState.BATTLE_ITEMS[step.item].name
	elif target == defender:
		prompt.text = "Выбери защитника с жёлтой полоской здоровья."
	elif target == striker:
		prompt.text = "Выбери напарника с голубой полоской здоровья."
	else:
		prompt.text = "Нажми «%s» внизу." % target.text
	explanation.text = "Попробуй нажать туда, куда указывает белая рамка." if reminder_time > 0.0 else step.why
	if target is Control:
		var rect: Rect2 = target.get_global_rect().grow(3)
		pointer.position = rect.position
		pointer.size = rect.size
	else:
		var cell = target if target.get_parent() == $Cells else get_cell_by_position(target.cell)
		var rect: Rect2 = cell.get_global_transform_with_canvas() * Rect2(-cell_visual_size / 2.0, cell_visual_size)
		pointer.position = rect.position
		pointer.size = rect.size

func _open_guide() -> void:
	guide.open_book(_guided())
	_refresh()

func _start_free_practice() -> void:
	chapter = LESSONS.size()
	if mode != "retreat":
		cancel_item_selection()
	items_drawer.hide()
	update_turn_label()
	if mode == "retreat":
		instruction_label.text = "Выбери клетку для отхода"
	_refresh()

func _allowed(target: CanvasItem) -> bool:
	if guide.visible or battle_finished or current_turn != Turn.PLAYER:
		return false
	if not _guided() or target == _expected(_step()):
		return true
	reminder_time = 1.4
	_refresh()
	return false

func _record(target: CanvasItem) -> void:
	reminder_time = 0.0
	if _guided() and target == _goal(_step()):
		step_index += 1
		if step_index == LESSONS[chapter].steps.size():
			step_index = 0
			chapter += 1
	_refresh()

func _on_unit_pressed(unit: Area2D) -> void:
	if board_open() and _allowed(unit):
		super(unit)
		_record(unit)

func _on_cell_pressed(cell: Area2D) -> void:
	if board_open() and _allowed(cell):
		super(cell)
		_record(cell)

func on_command(command: String) -> void:
	var button: Button = commands[command]
	if board_open() and _allowed(button):
		super(command)
		_record(button)
	elif button.toggle_mode:
		button.set_pressed_no_signal(mode == command)

func _on_items_pressed() -> void:
	if _allowed(items_button) or (_guided() and items_drawer.visible):
		super()
		_refresh()

func select_item(id: String) -> void:
	if _allowed(item_buttons[id]):
		super(id)
		_refresh()

func show_victory() -> void:
	super()
	result_title.add_theme_font_size_override("font_size", 19)
	result_title.offset_left = 12
	result_title.offset_right = 418
	var directions: Label = result_title.get_parent().get_node("NextLocation")
	directions.add_theme_font_override("font", ThemeDB.fallback_font)
	if GameState.is_level_unlocked(GameState.FIRST_BATTLE_LEVEL):
		directions.text = "На карте выбери уровень 3. Там тебя ждёт первый бой кампании."
	else:
		directions.text = "На карте пройди уровень 2, чтобы открыть первый бой кампании на уровне 3."
	directions.show()
