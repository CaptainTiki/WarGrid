extends Resource
class_name EntityPlacementData

enum HealthSpawnMode {
	FULL,
	PERCENT,
	CURRENT_VALUE,
}

@export var entity_id: StringName
@export var position: Vector3
@export var rotation_y: float = 0.0
@export var team_id: int = 1
@export var health_spawn_mode: HealthSpawnMode = HealthSpawnMode.FULL
@export var health_value: float = 1.0
