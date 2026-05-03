extends RefCounted
class_name PlacementValidationResult

var is_valid: bool = false
var reason: String = ""
var local_position: Vector3 = Vector3.ZERO
var playable_cell: Vector2i = Vector2i(-1, -1)

static func valid(local_position: Vector3, playable_cell: Vector2i = Vector2i(-1, -1)) -> RefCounted:
	var result := new()
	result.is_valid = true
	result.reason = "Valid"
	result.local_position = local_position
	result.playable_cell = playable_cell
	return result

static func invalid(reason: String, local_position: Vector3 = Vector3.ZERO, playable_cell: Vector2i = Vector2i(-1, -1)) -> RefCounted:
	var result := new()
	result.is_valid = false
	result.reason = reason
	result.local_position = local_position
	result.playable_cell = playable_cell
	return result
