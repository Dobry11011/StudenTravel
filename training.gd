extends Node2D

@onready var arena = $BattleArena
@onready var lesson: Panel = $Tutorial/Lesson
@onready var hint: Label = $Tutorial/Lesson/Hint


func _ready() -> void:
	arena.instruction_label.hide()
	_update_lesson()


func _process(_delta: float) -> void:
	_update_lesson()


func _update_lesson() -> void:
	lesson.visible = not (arena.battle_finished or arena.menu_panel.visible or arena.items_drawer.visible)
	if not lesson.visible:
		return

	var instruction: String
	if arena.current_turn == arena.Turn.AI:
		instruction = "Ход противника. Когда он закончится, союзники смогут действовать снова."
	elif arena.selecting_item != "":
		instruction = "Нажми на подходящую цель, чтобы применить выбранный предмет."
	elif arena.selected_unit != null:
		if not arena.attack_targets.is_empty():
			instruction = "Нажми на подсвеченного врага рядом с союзником, чтобы атаковать."
		else:
			instruction = "Нажми на подсвеченную клетку, чтобы подойти ближе к противнику."
	elif arena.player_action_count > 0:
		instruction = "Выбери другого союзника. Когда оба закончат действия, начнётся ход противника."
	else:
		instruction = "Нажми на союзника. Подсветка покажет, куда он может пойти и кого атаковать."
	if hint.text != instruction:
		hint.text = instruction
