extends CharacterBody2D

const SPEED = 150.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var joystick = $CanvasLayer/Joystick
@onready var interact_button: Button = $CanvasLayer/InteractButton
@onready var player_collider: CollisionShape2D = $CollisionShape2D

var last_direction := "down"
var interaction_targets: Array[Area2D] = []


func add_interaction_target(target: Area2D) -> void:
	interaction_targets.append(target)
	target.tree_exiting.connect(remove_interaction_target.bind(target), CONNECT_ONE_SHOT)
	interact_button.show()


func remove_interaction_target(target: Area2D) -> void:
	interaction_targets.erase(target)
	var on_target_exiting := remove_interaction_target.bind(target)
	if target.tree_exiting.is_connected(on_target_exiting):
		target.tree_exiting.disconnect(on_target_exiting)
	if is_instance_valid(interact_button):
		interact_button.visible = not interaction_targets.is_empty()


func _on_interact_pressed() -> void:
	var closest: Area2D
	var closest_distance := INF
	for target in interaction_targets:
		var distance := player_collider.global_position.distance_squared_to(target.interaction_position())
		if distance < closest_distance:
			closest = target
			closest_distance = distance
	if closest:
		closest.interact()

func _physics_process(_delta):
	var direction = Vector2.ZERO
	
	if joystick:
		direction = joystick.pos_vector
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		choose_animation(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		play_idle_animation()

	move_and_slide()

func choose_animation(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		animated_sprite.play("walk_side")
		
		animated_sprite.flip_h = dir.x < 0 
		
		last_direction = "side"
	else:
		animated_sprite.flip_h = false
		if dir.y > 0:
			animated_sprite.play("walk_down")
			last_direction = "down"
		else:
			animated_sprite.play("walk_up")
			last_direction = "up"


func play_idle_animation():
	if last_direction == "side":
		animated_sprite.play("idle_side") 
	elif last_direction == "up":
		animated_sprite.play("idle_up")
	else:
		animated_sprite.play("idle_down")
