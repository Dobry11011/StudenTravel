extends Area2D

signal unit_pressed(unit: Area2D)
signal defeated(unit: Area2D)

@export_enum("player", "enemy") var team := "player"
@export var cell := Vector2i.ZERO
@export var max_hp := 100
@export var attack := 10
var hp: int

@onready var selected_marker: Polygon2D = $SelectedMarker
@onready var stats_label: RichTextLabel = $StatsLabel
@onready var attack_marker: Polygon2D = $AttackMarker
@onready var damage_label: Label = $DamageLabel
var damage_tween: Tween

func _ready() -> void:
	$TouchScreenButton.pressed.connect(_on_touch_screen_button_pressed)
	selected_marker.visible = false
	stats_label.visible = false
	stats_label.add_theme_font_size_override("normal_font_size", 10)
	attack_marker.visible = false
	hp = max_hp
	update_stats_label()

	if team == "enemy":
		$Sprite2D.modulate = Color("#d87882")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		unit_pressed.emit(self)
	elif event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		unit_pressed.emit(self)

func set_selected(value: bool) -> void:
	selected_marker.visible = value

func set_attackable(value: bool) -> void:
	attack_marker.visible = value

func set_stats_visible(value: bool) -> void:
	stats_label.visible = value

func take_damage(damage: int) -> void:
	if team == "player" and hp > 0 and damage > 0:
		GameSettings.vibrate()
	hp = maxi(hp - damage, 0)
	update_stats_label()
	if hp == 0:
		defeated.emit(self)
		visible = false

func show_damage(damage: int) -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()

	damage_label.text = "-%d" % damage
	damage_label.position = Vector2(-30, -58)
	damage_label.modulate = Color(1.0, 0.1, 0.1, 1.0)
	damage_label.visible = true

	damage_tween = create_tween()
	damage_tween.set_parallel()
	damage_tween.tween_property(
		damage_label,
		"position",
		Vector2(-30, -95),
		0.7
	)
	damage_tween.tween_property(
		damage_label,
		"modulate:a",
		0.0,
		0.7
	)
	damage_tween.chain().tween_callback(_hide_damage_label)

func show_effect(value: int, effect_type: String) -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()

	if effect_type == "heal":
		damage_label.text = "+%d HP" % value
		damage_label.modulate = Color(0.15, 1.0, 0.15, 1.0)
	elif effect_type == "attack":
		damage_label.text = "+%d ATK" % value
		damage_label.modulate = Color(1.0, 0.9, 0.15, 1.0)
	else:
		damage_label.text = "+%d" % value
		damage_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	damage_label.position = Vector2(-40, -58)
	damage_label.visible = true

	damage_tween = create_tween()
	damage_tween.set_parallel()
	damage_tween.tween_property(damage_label, "position", Vector2(-40, -95), 0.7)
	damage_tween.tween_property(damage_label, "modulate:a", 0.0, 0.7)
	damage_tween.chain().tween_callback(_hide_damage_label)

func _hide_damage_label() -> void:
	damage_label.visible = false
	damage_label.modulate.a = 1.0
	damage_label.position = Vector2(-30, -58)

func update_stats_label() -> void:
	stats_label.text = "[color=#44DD44]HP: %d/%d[/color]\n[color=#FF4444]ATK: %d[/color]" % [hp, max_hp, attack]

func _on_touch_screen_button_pressed() -> void:
	unit_pressed.emit(self)
