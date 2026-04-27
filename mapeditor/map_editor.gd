extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var tool_dock: EditorToolDock = $CanvasLayer/EditorToolDock

var camera: Camera3D
var brush_preview: BrushPreview
var height_brush_tool := HeightBrushTool.new()
var smooth_brush_tool := SmoothBrushTool.new()
var flatten_brush_tool := FlattenBrushTool.new()
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT

func _ready() -> void:
	add_child(height_brush_tool)
	add_child(smooth_brush_tool)
	add_child(flatten_brush_tool)
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
			var current_radius := _get_active_brush_data().radius
			_set_brush_radius(current_radius + 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var current_radius := _get_active_brush_data().radius
			_set_brush_radius(current_radius - 1.0)
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

	var active_brush_data := _get_active_brush_data()
	brush_preview.set_radius(active_brush_data.radius)
	brush_preview.show_at(_last_pick_point)

func _apply_active_brush(_delta: float) -> void:
	if _last_pick_point == null:
		return

	if not _painting:
		return

	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			height_brush_tool.apply_stroke_sample(terrain, _last_pick_point, _lowering)
		EditorToolDock.TOOL_SMOOTH:
			smooth_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.apply_stroke_sample(terrain, _last_pick_point)

func _begin_brush_stroke(lowering: bool) -> void:
	if _last_pick_point == null:
		return

	_painting = true
	_lowering = lowering

	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			terrain.begin_height_brush_stroke()
			height_brush_tool.begin_stroke(terrain, _last_pick_point, _lowering)
		EditorToolDock.TOOL_SMOOTH:
			terrain.begin_smooth_brush_stroke()
			smooth_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.begin_stroke(terrain, _last_pick_point)

func _end_brush_stroke() -> void:
	if not _painting:
		return

	_painting = false
	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			height_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_SMOOTH:
			smooth_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.end_stroke(terrain)

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
	var clamped_strength := clampf(strength, 0.1, 16.0)
	height_brush_tool.brush_data.strength = clamped_strength
	smooth_brush_tool.brush_data.strength = clamped_strength
	flatten_brush_tool.brush_data.strength = clamped_strength
	tool_dock.set_brush_strength(clamped_strength)

func _on_brush_falloff_changed(falloff: float) -> void:
	var clamped_falloff := clampf(falloff, 0.25, 4.0)
	height_brush_tool.brush_data.falloff = clamped_falloff
	smooth_brush_tool.brush_data.falloff = clamped_falloff
	flatten_brush_tool.brush_data.falloff = clamped_falloff
	tool_dock.set_brush_falloff(clamped_falloff)

func _set_brush_radius(radius: float) -> void:
	var clamped_radius := clampf(radius, 1.0, 32.0)
	height_brush_tool.brush_data.radius = clamped_radius
	smooth_brush_tool.brush_data.radius = clamped_radius
	flatten_brush_tool.brush_data.radius = clamped_radius
	brush_preview.set_radius(clamped_radius)
	tool_dock.set_brush_radius(clamped_radius)

func _get_active_brush_data() -> TerrainBrushData:
	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			return height_brush_tool.brush_data
		EditorToolDock.TOOL_SMOOTH:
			return smooth_brush_tool.brush_data
		EditorToolDock.TOOL_FLATTEN:
			return flatten_brush_tool.brush_data
		_:
			return height_brush_tool.brush_data
