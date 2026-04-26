extends Node
class_name HeightBrushTool

@export var brush_data := TerrainBrushData.new()

func apply(terrain: Terrain, local_center: Vector3, lower: bool, delta: float) -> void:
	if terrain == null:
		return

	var direction := -1.0 if lower else 1.0
	terrain.apply_height_brush(
		local_center,
		brush_data.radius,
		brush_data.strength * direction * delta
	)
