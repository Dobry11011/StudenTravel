extends Node2D

@onready var arena = $BattleArena
@onready var lesson: Panel = $Tutorial/Lesson
@onready var hint: Label = $Tutorial/Lesson/Hint

var practiced_with_item := false


func _ready() -> void:
	arena.instruction_label.hide()
	_update_lesson()


func _process(_delta: float) -> void:
	_update_lesson()


func _update_lesson() -> void:
	if arena.items_used_this_turn > 0:
		practiced_with_item = true
	lesson.visible = not (arena.battle_finished or arena.menu_panel.visible)
	if not lesson.visible:
		return

	var instruction: String
	if arena.current_turn == arena.Turn.AI:
		instruction = "Ход противника. Когда он закончится, союзники смогут действовать снова."
	elif arena.selecting_item != "":
		instruction = _item_target_hint()
	elif arena.items_drawer.visible:
		if not arena.can_use_item():
			instruction = "Лимит предметов на этот ход исчерпан. Они снова будут доступны после хода противника."
		elif not practiced_with_item:
			instruction = "Нажми на предмет в списке. Для первой попытки выбери «Медавуху»: она усилит атаку союзника."
		else:
			instruction = "Выбери предмет. Под названием указаны его эффект и оставшееся количество."
	elif arena.selected_unit != null:
		if not arena.attack_targets.is_empty():
			instruction = "Нажми на подсвеченного врага рядом с союзником, чтобы атаковать."
		else:
			instruction = "Нажми на подсвеченную клетку, чтобы подойти ближе к противнику."
	elif arena.player_action_count > 0:
		instruction = "Выбери другого союзника. Когда оба закончат действия, начнётся ход противника."
	elif not practiced_with_item:
		instruction = "Нажми на союзника для хода. Чтобы попробовать предмет, открой «Предметы» справа."
	else:
		instruction = "Нажми на союзника. Подсветка покажет, куда он может пойти и кого атаковать."
	if hint.text != instruction:
		hint.text = instruction

func _item_target_hint() -> String:
	match arena.selecting_item:
		"medkit":
			return "Нажми на раненого союзника, чтобы восстановить ему здоровье."
		"strength":
			return "Нажми на подсвеченного союзника. Его атака усилится на два хода."
		"adrenaline":
			return "Нажми на подсвеченного союзника, который ещё не действовал. Он получит два дополнительных действия, но пропустит следующий ход."
		"bomb":
			return "Нажми на подсвеченного врага. Взрыв заденет его и соседних противников."
		"brick":
			return "Нажми на подсвеченного врага. Он пропустит следующий ход."
	return ""
