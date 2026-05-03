extends PanelContainer
class_name EditorPlaceholderDock

@onready var mode_label: Label = %ModeLabel

func set_mode_label(mode_name: String) -> void:
	mode_label.text = "%s tools coming soon." % mode_name
