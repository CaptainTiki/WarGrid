extends Node3D
class_name PlayerCameraRig

@export var move_speed := 42.0
@export var fast_move_multiplier := 2.0
@export var vertical_step := 8.0
@export var min_height := 20.0
@export var max_height := 240.0
@export var initial_offset := Vector3(64.0, 90.0, 96.0)

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

func _ready() -> void:
	camera.current = true

func _process(delta: float) -> void:
	_update_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_vertical(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_vertical(-1.0)
			get_viewport().set_input_as_handled()

func frame_point(center: Vector3) -> void:
	global_position = center + initial_offset

func get_camera() -> Camera3D:
	return camera

func move_vertical(amount: float) -> void:
	global_position.y = clampf(global_position.y + amount * vertical_step, min_height, max_height)

func _update_movement(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0

	if move == Vector3.ZERO:
		return

	move = move.normalized()
	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_move_multiplier
	global_position += move * speed * delta
