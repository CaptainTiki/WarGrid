extends Node3D
class_name EditorCameraRig

@export var move_speed := 36.0
@export var fast_move_multiplier := 2.5
@export var mouse_sensitivity := 0.004
@export var min_pitch_degrees := -85.0
@export var max_pitch_degrees := -20.0
@export var initial_offset := Vector3(45.0, 75.0, 75.0)

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

var _rotating := false
var _yaw := 0.0
var _pitch := deg_to_rad(-55.0)

func _ready() -> void:
	camera.current = true
	_apply_rotation()

func _process(delta: float) -> void:
	_update_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rotating = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _rotating:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(
			_pitch,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		_apply_rotation()
		get_viewport().set_input_as_handled()

func frame_point(center: Vector3) -> void:
	global_position = center + initial_offset
	var direction := (center - global_position).normalized()
	var flat_length := Vector2(direction.x, direction.z).length()
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = clamp(
		atan2(direction.y, flat_length),
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	_apply_rotation()

func get_camera() -> Camera3D:
	return camera

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
	if Input.is_key_pressed(KEY_Q):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		move.y += 1.0

	if move == Vector3.ZERO:
		return

	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_basis.x
	right.y = 0.0
	right = right.normalized()
	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_move_multiplier

	global_position += (right * move.x + forward * move.z + Vector3.UP * move.y) * speed * delta

func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	pitch_pivot.rotation = Vector3(_pitch, 0.0, 0.0)
