extends Node2D

@onready var label = $Label
@onready var anim_player = $AnimationPlayer

func start(text_message: String):
	label.text = text_message
	anim_player.play("show_text") # Запускаем анимацию исчезновения
# Этот метод автоматически вызовется, когда любая анимация завершится
func _on_animation_player_animation_finished(anim_name: String) -> void:
	if anim_name == "show_text":
		queue_free() # Полностью удаляет облачко из игры
