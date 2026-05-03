extends PanelContainer
class_name EditorMenuBar

signal new_map_requested(playable_chunks: Vector2i)
signal save_map_requested
signal load_map_requested
signal preferences_requested
signal close_requested
signal grid_visibility_changed(is_visible: bool)
signal placement_overlay_visibility_changed(is_visible: bool)
signal terrain_tool_requested
signal entities_tool_requested
signal resources_tool_requested
signal regions_tool_requested
signal triggers_tool_requested
signal debug_tool_requested

const MENU_NEW_MAP := 0
const MENU_SAVE_MAP := 1
const MENU_LOAD_MAP := 2
const MENU_PREFERENCES := 10
const MENU_SHOW_GRID := 20
const MENU_SHOW_PLACEMENT_OVERLAY := 21
const MAX_PLAYABLE_CHUNKS := 512

@onready var file_menu_button: MenuButton = %FileMenuButton
@onready var edit_menu_button: MenuButton = %EditMenuButton
@onready var view_menu_button: MenuButton = %ViewMenuButton
@onready var terrain_button: Button = %TerrainButton
@onready var entities_button: Button = %EntitiesButton
@onready var resources_button: Button = %ResourcesButton
@onready var regions_button: Button = %RegionsButton
@onready var triggers_button: Button = %TriggersButton
@onready var debug_button: Button = %DebugButton
@onready var close_button: Button = %CloseButton
@onready var new_map_dialog: ConfirmationDialog = %NewMapDialog
@onready var width_spin_box: SpinBox = %WidthSpinBox
@onready var length_spin_box: SpinBox = %LengthSpinBox

func _ready() -> void:
	_configure_file_menu()
	_configure_edit_menu()
	_configure_view_menu()
	terrain_button.pressed.connect(_on_terrain_pressed)
	entities_button.pressed.connect(_on_entities_pressed)
	resources_button.pressed.connect(_on_resources_pressed)
	regions_button.pressed.connect(_on_regions_pressed)
	triggers_button.pressed.connect(_on_triggers_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	close_button.pressed.connect(_on_close_pressed)
	new_map_dialog.confirmed.connect(_on_new_map_confirmed)
	width_spin_box.min_value = 1
	width_spin_box.max_value = MAX_PLAYABLE_CHUNKS
	width_spin_box.step = 1
	length_spin_box.min_value = 1
	length_spin_box.max_value = MAX_PLAYABLE_CHUNKS
	length_spin_box.step = 1

func set_current_playable_chunks(playable_chunks: Vector2i) -> void:
	width_spin_box.value = clampi(playable_chunks.x, 1, MAX_PLAYABLE_CHUNKS)
	length_spin_box.value = clampi(playable_chunks.y, 1, MAX_PLAYABLE_CHUNKS)

func set_active_tool_mode(mode: StringName) -> void:
	terrain_button.button_pressed = mode == &"terrain"
	entities_button.button_pressed = mode == &"entities"
	resources_button.button_pressed = mode == &"resources"
	regions_button.button_pressed = mode == &"regions"
	triggers_button.button_pressed = mode == &"triggers"
	debug_button.button_pressed = mode == &"debug"

func set_grid_visible(is_visible: bool) -> void:
	var popup := view_menu_button.get_popup()
	var index := popup.get_item_index(MENU_SHOW_GRID)
	if index >= 0:
		popup.set_item_checked(index, is_visible)

func set_placement_overlay_visible(is_visible: bool) -> void:
	var popup := view_menu_button.get_popup()
	var index := popup.get_item_index(MENU_SHOW_PLACEMENT_OVERLAY)
	if index >= 0:
		popup.set_item_checked(index, is_visible)

func _configure_file_menu() -> void:
	var popup := file_menu_button.get_popup()
	popup.clear()
	popup.add_item("New Map...", MENU_NEW_MAP)
	popup.add_separator()
	popup.add_item("Save Map", MENU_SAVE_MAP)
	popup.add_item("Load Map", MENU_LOAD_MAP)
	popup.id_pressed.connect(_on_file_menu_id_pressed)

func _configure_edit_menu() -> void:
	var popup := edit_menu_button.get_popup()
	popup.clear()
	popup.add_item("Preferences...", MENU_PREFERENCES)
	popup.id_pressed.connect(_on_edit_menu_id_pressed)

func _configure_view_menu() -> void:
	var popup := view_menu_button.get_popup()
	popup.clear()
	popup.add_check_item("Show Grid", MENU_SHOW_GRID)
	popup.add_check_item("Show Placement Overlay", MENU_SHOW_PLACEMENT_OVERLAY)
	popup.id_pressed.connect(_on_view_menu_id_pressed)

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		MENU_NEW_MAP:
			new_map_dialog.popup_centered()
		MENU_SAVE_MAP:
			save_map_requested.emit()
		MENU_LOAD_MAP:
			load_map_requested.emit()

func _on_edit_menu_id_pressed(id: int) -> void:
	if id == MENU_PREFERENCES:
		preferences_requested.emit()

func _on_view_menu_id_pressed(id: int) -> void:
	if id != MENU_SHOW_GRID and id != MENU_SHOW_PLACEMENT_OVERLAY:
		return
	var popup := view_menu_button.get_popup()
	var index := popup.get_item_index(id)
	if index < 0:
		return
	var is_visible := not popup.is_item_checked(index)
	popup.set_item_checked(index, is_visible)
	if id == MENU_SHOW_GRID:
		grid_visibility_changed.emit(is_visible)
	else:
		placement_overlay_visibility_changed.emit(is_visible)

func _on_close_pressed() -> void:
	close_requested.emit()

func _on_terrain_pressed() -> void:
	terrain_tool_requested.emit()

func _on_entities_pressed() -> void:
	entities_tool_requested.emit()

func _on_resources_pressed() -> void:
	resources_tool_requested.emit()

func _on_regions_pressed() -> void:
	regions_tool_requested.emit()

func _on_triggers_pressed() -> void:
	triggers_tool_requested.emit()

func _on_debug_pressed() -> void:
	debug_tool_requested.emit()

func _on_new_map_confirmed() -> void:
	new_map_requested.emit(Vector2i(int(width_spin_box.value), int(length_spin_box.value)))
