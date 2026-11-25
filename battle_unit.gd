extends Area2D

@export_enum("player", "enemy") var team := "player"
@export var cell := Vector2i.ZERO
@export var max_hp := 100
@export var attack := 10
@export var reinforcement := false
var hp: int:
	set(value):
		hp = value
		queue_redraw()
var actions_left := 1:
	set(value):
		actions_left = value
		queue_redraw()
var stepped := false
var used_adrenaline := false
var strength_turns := 0
var stunned_turns := 0
var marked := false:
	set(value):
		marked = value
		queue_redraw()
var guarding := false:
	set(value):
		guarding = value
		queue_redraw()

@onready var selected_marker: Polygon2D = $SelectedMarker
@onready var stats_label: RichTextLabel = $StatsLabel
@onready var attack_marker: Polygon2D = $AttackMarker
@onready var damage_label: Label = $DamageLabel
var damage_tween: Tween

func _ready() -> void:
	$TouchScreenButton.hide()
	input_pickable = false
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_label.offset_left = -68
	stats_label.offset_right = 68
	stats_label.add_theme_color_override("font_outline_color", Color("#171820"))
	stats_label.add_theme_constant_override("outline_size", 3)
	selected_marker.visible = false
	stats_label.visible = false
	stats_label.add_theme_font_size_override("normal_font_size", 10)
	attack_marker.visible = false
	hp = max_hp
	update_stats_label()

	if team == "enemy":
		$Sprite2D.modulate = Color("#d87882")

func _draw() -> void:
	var bar := Rect2(-20, -30, 40, 5)
	var tint := Color("#ee786b")
	if team == "player":
		tint = Color("#f4c961") if name == &"Player1" else Color("#63cced")
	if team == "player" and actions_left == 0:
		tint = tint.darkened(0.45)
	draw_rect(bar.grow(1), Color("#222237"))
	bar.size.x *= clampf(float(hp) / max_hp, 0.0, 1.0)
	draw_rect(bar, tint)
	if guarding or marked:
		draw_circle(Vector2(25, -28), 4, Color("#84ecca") if guarding else Color("#ffce5c"))

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
