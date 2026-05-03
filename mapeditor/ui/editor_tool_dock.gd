extends PanelContainer
class_name EditorToolDock

signal tool_selected(tool_id: int)
signal brush_radius_changed(radius: float)
signal brush_strength_changed(strength: float)
signal brush_falloff_changed(falloff: float)
signal material_channel_changed(channel: int)
signal walkable_value_changed(value: int)
signal buildable_value_changed(value: int)
signal fow_height_changed(height: int)
signal overlay_enabled_changed(enabled: bool)
signal overlay_mode_changed(mode: int)

const TOOL_HEIGHT := 0
const TOOL_SMOOTH := 1
const TOOL_FLATTEN := 2
const TOOL_PAINT_MATERIAL := 3
const TOOL_WALKABLE_PAINT := 4
const TOOL_BUILDABLE_PAINT := 5
const TOOL_FOW_HEIGHT_PAINT := 6

@onready var raise_lower_button: Button = %RaiseLowerButton
@onready var smooth_button: Button = %SmoothButton
@onready var flatten_button: Button = %FlattenButton
@onready var paint_material_button: Button = %PaintMaterialButton
@onready var walkable_paint_button: Button = %WalkablePaintButton
@onready var buildable_paint_button: Button = %BuildablePaintButton
@onready var fow_height_paint_button: Button = %FowHeightPaintButton
@onready var tool_name_label: Label = %ToolNameLabel
@onready var radius_slider: HSlider = %RadiusSlider
@onready var radius_value_label: Label = %RadiusValueLabel
@onready var strength_slider: HSlider = %StrengthSlider
@onready var strength_value_label: Label = %StrengthValueLabel
@onready var falloff_slider: HSlider = %FalloffSlider
@onready var falloff_value_label: Label = %FalloffValueLabel
@onready var strength_row: Control = %StrengthRow
@onready var falloff_row: Control = %FalloffRow
@onready var material_properties_panel: VBoxContainer = %MaterialPropertiesPanel
@onready var material_channel_option: OptionButton = %MaterialChannelOption
@onready var walkable_properties_panel: VBoxContainer = %WalkablePropertiesPanel
@onready var walkable_value_option: OptionButton = %WalkableValueOption
@onready var buildable_properties_panel: VBoxContainer = %BuildablePropertiesPanel
@onready var buildable_value_option: OptionButton = %BuildableValueOption
@onready var fow_height_properties_panel: VBoxContainer = %FowHeightPropertiesPanel
@onready var fow_height_option: OptionButton = %FowHeightOption
@onready var overlay_enabled_check_box: CheckBox = %OverlayEnabledCheckBox
@onready var overlay_mode_option: OptionButton = %OverlayModeOption

var _active_tool := TOOL_HEIGHT
var _syncing := false

func _ready() -> void:
	raise_lower_button.pressed.connect(_select_raise_lower_tool)
	smooth_button.pressed.connect(_select_smooth_tool)
	flatten_button.pressed.connect(_select_flatten_tool)
	paint_material_button.pressed.connect(_select_paint_material_tool)
	walkable_paint_button.pressed.connect(_select_walkable_paint_tool)
	buildable_paint_button.pressed.connect(_select_buildable_paint_tool)
	fow_height_paint_button.pressed.connect(_select_fow_height_paint_tool)
	radius_slider.value_changed.connect(_on_radius_slider_changed)
	strength_slider.value_changed.connect(_on_strength_slider_changed)
	falloff_slider.value_changed.connect(_on_falloff_slider_changed)
	material_channel_option.item_selected.connect(_on_material_channel_selected)
	walkable_value_option.item_selected.connect(_on_walkable_value_selected)
	buildable_value_option.item_selected.connect(_on_buildable_value_selected)
	fow_height_option.item_selected.connect(_on_fow_height_selected)
	overlay_enabled_check_box.toggled.connect(_on_overlay_enabled_toggled)
	overlay_mode_option.item_selected.connect(_on_overlay_mode_selected)
	_configure_material_channel_option()
	_configure_walkable_value_option()
	_configure_buildable_value_option()
	_configure_fow_height_option()
	_configure_overlay_mode_option()
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
	fow_height_paint_button.button_pressed = tool_id == TOOL_FOW_HEIGHT_PAINT
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
		TOOL_FOW_HEIGHT_PAINT:
			tool_name_label.text = "FOW Height Paint"
	material_properties_panel.visible = tool_id == TOOL_PAINT_MATERIAL
	walkable_properties_panel.visible = tool_id == TOOL_WALKABLE_PAINT
	buildable_properties_panel.visible = tool_id == TOOL_BUILDABLE_PAINT
	fow_height_properties_panel.visible = tool_id == TOOL_FOW_HEIGHT_PAINT
	_set_continuous_brush_controls_enabled(not _is_categorical_paint_tool(tool_id))

func set_material_channel(channel: int) -> void:
	_syncing = true
	material_channel_option.select(clampi(channel, 0, 3))
	_syncing = false

func set_walkable_value(value: int) -> void:
	_syncing = true
	walkable_value_option.select(clampi(value, TerrainMapData.Walkable.ALL, TerrainMapData.Walkable.NONE))
	_syncing = false

func set_buildable_value(value: int) -> void:
	_syncing = true
	buildable_value_option.select(clampi(value, TerrainMapData.Buildable.OPEN, TerrainMapData.Buildable.BLOCKED))
	_syncing = false

func set_fow_height(height: int) -> void:
	_syncing = true
	fow_height_option.select(clampi(height, 0, 3))
	_syncing = false

func set_overlay_enabled(enabled: bool) -> void:
	_syncing = true
	overlay_enabled_check_box.button_pressed = enabled
	_syncing = false

func set_overlay_mode(mode: int) -> void:
	_syncing = true
	overlay_mode_option.select(clampi(mode, 0, 3))
	_syncing = false

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

func _select_fow_height_paint_tool() -> void:
	_select_tool(TOOL_FOW_HEIGHT_PAINT)

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

func _configure_material_channel_option() -> void:
	material_channel_option.clear()
	material_channel_option.add_item("Material 0 - Grass", 0)
	material_channel_option.add_item("Material 1 - Dirt", 1)
	material_channel_option.add_item("Material 2 - Rock", 2)
	material_channel_option.add_item("Material 3 - Sand", 3)
	material_channel_option.select(0)

func _on_material_channel_selected(index: int) -> void:
	if not _syncing:
		material_channel_changed.emit(material_channel_option.get_item_id(index))

func _configure_walkable_value_option() -> void:
	walkable_value_option.clear()
	walkable_value_option.add_item("All", TerrainMapData.Walkable.ALL)
	walkable_value_option.add_item("Air", TerrainMapData.Walkable.AIR)
	walkable_value_option.add_item("None", TerrainMapData.Walkable.NONE)
	walkable_value_option.select(0)

func _on_walkable_value_selected(index: int) -> void:
	if not _syncing:
		walkable_value_changed.emit(walkable_value_option.get_item_id(index))

func _configure_buildable_value_option() -> void:
	buildable_value_option.clear()
	buildable_value_option.add_item("Open", TerrainMapData.Buildable.OPEN)
	buildable_value_option.add_item("Blocked", TerrainMapData.Buildable.BLOCKED)
	buildable_value_option.select(0)

func _on_buildable_value_selected(index: int) -> void:
	if not _syncing:
		buildable_value_changed.emit(buildable_value_option.get_item_id(index))

func _configure_fow_height_option() -> void:
	fow_height_option.clear()
	fow_height_option.add_item("Height 0", 0)
	fow_height_option.add_item("Height 1", 1)
	fow_height_option.add_item("Height 2", 2)
	fow_height_option.add_item("Height 3", 3)
	fow_height_option.select(0)

func _on_fow_height_selected(index: int) -> void:
	if not _syncing:
		fow_height_changed.emit(fow_height_option.get_item_id(index))

func _configure_overlay_mode_option() -> void:
	overlay_mode_option.clear()
	overlay_mode_option.add_item("None", TerrainMapData.OverlayMode.NONE)
	overlay_mode_option.add_item("Walkable", TerrainMapData.OverlayMode.WALKABLE)
	overlay_mode_option.add_item("Buildable", TerrainMapData.OverlayMode.BUILDABLE)
	overlay_mode_option.add_item("FOW Height", TerrainMapData.OverlayMode.FOW_HEIGHT)
	overlay_mode_option.select(0)

func _on_overlay_enabled_toggled(enabled: bool) -> void:
	if not _syncing:
		overlay_enabled_changed.emit(enabled)

func _on_overlay_mode_selected(index: int) -> void:
	if not _syncing:
		overlay_mode_changed.emit(overlay_mode_option.get_item_id(index))

func _set_continuous_brush_controls_enabled(enabled: bool) -> void:
	strength_slider.editable = enabled
	falloff_slider.editable = enabled
	var row_color := Color.WHITE if enabled else Color(0.55, 0.55, 0.55, 1.0)
	strength_row.modulate = row_color
	falloff_row.modulate = row_color

func _is_categorical_paint_tool(tool_id: int) -> bool:
	return tool_id == TOOL_WALKABLE_PAINT or tool_id == TOOL_BUILDABLE_PAINT or tool_id == TOOL_FOW_HEIGHT_PAINT
