extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var tool_dock: EditorToolDock = $CanvasLayer/EditorToolDock

var camera: Camera3D
var brush_preview: BrushPreview
var height_brush_tool := HeightBrushTool.new()
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT

func _ready() -> void:
	add_child(height_brush_tool)
	_ensure_light()
	camera_rig.frame_point(terrain.get_center_position())
	camera = camera_rig.get_camera()
	tool_dock.tool_selected.connect(_on_tool_selected)
	tool_dock.brush_radius_changed.connect(_on_brush_radius_changed)
	tool_dock.brush_strength_changed.connect(_on_brush_strength_changed)
	tool_dock.brush_falloff_changed.connect(_on_brush_falloff_changed)
	tool_dock.set_active_tool(_active_tool)
	tool_dock.set_brush_radius(height_brush_tool.brush_data.radius)
	tool_dock.set_brush_strength(height_brush_tool.brush_data.strength)
	tool_dock.set_brush_falloff(height_brush_tool.brush_data.falloff)
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()

func _process(delta: float) -> void:
	_update_brush()
	_apply_active_brush(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_brush_radius(height_brush_tool.brush_data.radius + 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_brush_radius(height_brush_tool.brush_data.radius - 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_update_brush()
			_begin_brush_stroke(Input.is_key_pressed(KEY_SHIFT))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_end_brush_stroke()
			get_viewport().set_input_as_handled()

func _update_brush() -> void:
	_last_pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position(), _painting)
	if _last_pick_point == null:
		brush_preview.hide_preview()
		return

	brush_preview.set_radius(height_brush_tool.brush_data.radius)
	brush_preview.show_at(_last_pick_point)

func _apply_active_brush(_delta: float) -> void:
	if _last_pick_point == null:
		return

	if not _painting:
		return

	height_brush_tool.apply_stroke_sample(terrain, _last_pick_point, _lowering)

func _begin_brush_stroke(lowering: bool) -> void:
	if _last_pick_point == null:
		return
	if _active_tool != EditorToolDock.TOOL_HEIGHT:
		return

	_painting = true
	_lowering = lowering
	terrain.begin_height_brush_stroke()
	height_brush_tool.begin_stroke(terrain, _last_pick_point, _lowering)

func _end_brush_stroke() -> void:
	if not _painting:
		return

	_painting = false
	height_brush_tool.end_stroke(terrain)

func _ensure_light() -> void:
	if has_node("Sun"):
		return

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)

func _on_tool_selected(tool_id: int) -> void:
	_end_brush_stroke()
	_active_tool = tool_id
	tool_dock.set_active_tool(_active_tool)

func _on_brush_radius_changed(radius: float) -> void:
	_set_brush_radius(radius)

func _on_brush_strength_changed(strength: float) -> void:
	height_brush_tool.brush_data.strength = clampf(strength, 0.1, 16.0)
	tool_dock.set_brush_strength(height_brush_tool.brush_data.strength)

func _on_brush_falloff_changed(falloff: float) -> void:
	height_brush_tool.brush_data.falloff = clampf(falloff, 0.25, 4.0)
	tool_dock.set_brush_falloff(height_brush_tool.brush_data.falloff)

func _set_brush_radius(radius: float) -> void:
	height_brush_tool.brush_data.radius = clampf(radius, 1.0, 32.0)
	brush_preview.set_radius(height_brush_tool.brush_data.radius)
	tool_dock.set_brush_radius(height_brush_tool.brush_data.radius)
