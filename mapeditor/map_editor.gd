extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")

@onready var terrain: Terrain = $Terrain

var camera: Camera3D
var brush_preview: BrushPreview
var height_brush_tool := HeightBrushTool.new()
var _last_pick_point: Variant = null

func _ready() -> void:
	add_child(height_brush_tool)
	_ensure_editor_camera()
	_ensure_light()
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()
	_center_camera_on_terrain()

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_brush()
	_apply_active_brush(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			height_brush_tool.brush_data.radius = min(height_brush_tool.brush_data.radius + 1.0, 32.0)
			brush_preview.set_radius(height_brush_tool.brush_data.radius)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			height_brush_tool.brush_data.radius = max(height_brush_tool.brush_data.radius - 1.0, 1.0)
			brush_preview.set_radius(height_brush_tool.brush_data.radius)

func _update_brush() -> void:
	_last_pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position())
	if _last_pick_point == null:
		brush_preview.hide_preview()
		return

	brush_preview.set_radius(height_brush_tool.brush_data.radius)
	brush_preview.show_at(_last_pick_point)

func _apply_active_brush(delta: float) -> void:
	if _last_pick_point == null:
		return

	var raising := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var lowering := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (raising and Input.is_key_pressed(KEY_SHIFT))
	if not raising and not lowering:
		return

	height_brush_tool.apply(terrain, _last_pick_point, lowering, delta)

func _ensure_editor_camera() -> void:
	camera = get_viewport().get_camera_3d()
	if camera != null:
		return

	camera = Camera3D.new()
	camera.name = "EditorCamera"
	add_child(camera)
	camera.current = true
	camera.fov = 45.0

func _center_camera_on_terrain() -> void:
	var center := terrain.get_center_position()
	camera.position = center + Vector3(45.0, 75.0, 75.0)
	camera.look_at(center, Vector3.UP)

func _ensure_light() -> void:
	if has_node("Sun"):
		return

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)

func _update_camera(delta: float) -> void:
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

	var basis := camera.global_basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var speed := 36.0
	camera.global_position += (right * move.x + forward * move.z + Vector3.UP * move.y) * speed * delta
