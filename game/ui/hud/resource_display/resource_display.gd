extends HBoxContainer
class_name ResourceDisplay

@onready var _crystals_label: Label = $CrystalsLabel
@onready var _he3_label: Label = $He3Label

func _ready() -> void:
	_connect_resource_wallet()
	refresh()

func refresh() -> void:
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet == null or not wallet.has_method("get_amount"):
		_crystals_label.text = "Crystals: 0"
		_he3_label.text = "He3: 0"
		return
	_crystals_label.text = "Crystals: %d" % wallet.get_amount(&"crystals")
	_he3_label.text = "He3: %d" % wallet.get_amount(&"he3")

func _connect_resource_wallet() -> void:
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet == null:
		return
	if wallet.has_signal("resources_changed") and not wallet.resources_changed.is_connected(refresh):
		wallet.resources_changed.connect(refresh)
