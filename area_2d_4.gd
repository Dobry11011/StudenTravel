extends Area2D

# Ссылка на узел текста, который лежит внутри этой же зоны
@onready var dialogue_label: Label = $Label

# Список фраз конкретно для этого NPC
var phrases: Array[String] = [
	"Чтобы взаимодействовать с чем-либо
	нужно нажать пальцем по этому предмету"
]

func _ready() -> void:
	# Подключаем сигналы коллизии
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что мимо прошел именно ваш узел Player
	if body.name == "Player":
		show_random_phrase()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		# Сразу прячем текст, если игрок быстро убежал из зоны видимости
		dialogue_label.visible = false 

func show_random_phrase() -> void:
	if phrases.size() == 0: 
		return
	
	# Выбираем случайную фразу
	var random_index: int = randi() % phrases.size()
	dialogue_label.text = phrases[random_index]
	dialogue_label.visible = true
	
