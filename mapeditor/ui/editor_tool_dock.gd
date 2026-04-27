extends PanelContainer
class_name EditorToolDock

signal tool_selected(tool_id: int)
signal brush_radius_changed(radius: float)
signal brush_strength_changed(strength: float)
signal brush_falloff_changed(falloff: float)
signal save_map_requested
signal load_map_requested

const TOOL_HEIGHT := 0
const TOOL_SMOOTH := 1
const TOOL_FLATTEN := 2
const TOOL_PAINT_MATERIAL := 3
const TOOL_WALKABLE_PAINT := 4
const TOOL_BUILDABLE_PAINT := 5

@onready var raise_lower_button: Button = %RaiseLowerButton
@onready var smooth_button: Button = %SmoothButton
@onready var flatten_button: Button = %FlattenButton
@onready var paint_material_button: Button = %PaintMaterialButton
@onready var walkable_paint_button: Button = %WalkablePaintButton
@onready var buildable_paint_button: Button = %BuildablePaintButton
@onready var tool_name_label: Label = %ToolNameLabel
@onready var radius_slider: HSlider = %RadiusSlider
@onready var radius_value_label: Label = %RadiusValueLabel
@onready var strength_slider: HSlider = %StrengthSlider
@onready var strength_value_label: Label = %StrengthValueLabel
@onready var falloff_slider: HSlider = %FalloffSlider
@onready var falloff_value_label: Label = %FalloffValueLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton

var _active_tool := TOOL_HEIGHT
var _syncing := false

func _ready() -> void:
	raise_lower_button.pressed.connect(_select_raise_lower_tool)
	smooth_button.pressed.connect(_select_smooth_tool)
	flatten_button.pressed.connect(_select_flatten_tool)
	paint_material_button.pressed.connect(_select_paint_material_tool)
	walkable_paint_button.pressed.connect(_select_walkable_paint_tool)
	buildable_paint_button.pressed.connect(_select_buildable_paint_tool)
	radius_slider.value_changed.connect(_on_radius_slider_changed)
	strength_slider.value_changed.connect(_on_strength_slider_changed)
	falloff_slider.value_changed.connect(_on_falloff_slider_changed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	set_active_tool(_active_tool)
	set_brush_radius(radius_slider.value)
	set_brush_strength(strength_slider.value)
	set_brush_falloff(falloff_slider.value)

func set_active_tool(tool_id: int) -> void:
	_active_tool = tool_id
	_syncing = true
	raise_lower_button.button_pressed = tool_id == TOOL_HEIGHT
	smooth_button.button_pressed = tool_id == TOOL_SMOOTH
	flatten_button.button_pressed = tool_id == TOOL_FLATTEN
	paint_material_button.button_pressed = tool_id == TOOL_PAINT_MATERIAL
	walkable_paint_button.button_pressed = tool_id == TOOL_WALKABLE_PAINT
	buildable_paint_button.button_pressed = tool_id == TOOL_BUILDABLE_PAINT
	_syncing = false

	match tool_id:
		TOOL_HEIGHT:
			tool_name_label.text = "Raise/Lower"
		TOOL_SMOOTH:
			tool_name_label.text = "Smooth"
		TOOL_FLATTEN:
			tool_name_label.text = "Flatten"
		TOOL_PAINT_MATERIAL:
			tool_name_label.text = "Paint Material"
		TOOL_WALKABLE_PAINT:
			tool_name_label.text = "Walkable Paint"
		TOOL_BUILDABLE_PAINT:
			tool_name_label.text = "Buildable Paint"

func set_brush_radius(radius: float) -> void:
	_syncing = true
	radius_slider.value = radius
	_syncing = false
	_update_radius_label(radius)

func set_brush_strength(strength: float) -> void:
	_syncing = true
	strength_slider.value = strength
	_syncing = false
	_update_strength_label(strength)

func set_brush_falloff(falloff: float) -> void:
	_syncing = true
	falloff_slider.value = falloff
	_syncing = false
	_update_falloff_label(falloff)

func _select_raise_lower_tool() -> void:
	_select_tool(TOOL_HEIGHT)

func _select_smooth_tool() -> void:
	_select_tool(TOOL_SMOOTH)

func _select_flatten_tool() -> void:
	_select_tool(TOOL_FLATTEN)

func _select_paint_material_tool() -> void:
	_select_tool(TOOL_PAINT_MATERIAL)

func _select_walkable_paint_tool() -> void:
	_select_tool(TOOL_WALKABLE_PAINT)

func _select_buildable_paint_tool() -> void:
	_select_tool(TOOL_BUILDABLE_PAINT)

func _select_tool(tool_id: int) -> void:
	if _syncing:
		return
	set_active_tool(tool_id)
	tool_selected.emit(tool_id)

func _on_radius_slider_changed(value: float) -> void:
	_update_radius_label(value)
	if not _syncing:
		brush_radius_changed.emit(value)

func _on_strength_slider_changed(value: float) -> void:
	_update_strength_label(value)
	if not _syncing:
		brush_strength_changed.emit(value)

func _on_falloff_slider_changed(value: float) -> void:
	_update_falloff_label(value)
	if not _syncing:
		brush_falloff_changed.emit(value)

func _update_radius_label(radius: float) -> void:
	radius_value_label.text = "%.1fm" % radius

func _update_strength_label(strength: float) -> void:
	strength_value_label.text = "%.1f" % strength

func _update_falloff_label(falloff: float) -> void:
	falloff_value_label.text = "%.2f" % falloff

func _on_save_pressed() -> void:
	save_map_requested.emit()

func _on_load_pressed() -> void:
	load_map_requested.emit()
