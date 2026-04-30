extends RefCounted
class_name ProductionOrder

var recipe: Resource
var remaining_time: float = 0.0
var total_time: float = 0.0

func _init(order_recipe: Resource = null) -> void:
	recipe = order_recipe
	if recipe != null:
		total_time = maxf(recipe.build_time, 0.0)
		remaining_time = total_time

func get_progress_ratio() -> float:
	if total_time <= 0.0:
		return 1.0
	return clampf((total_time - remaining_time) / total_time, 0.0, 1.0)
