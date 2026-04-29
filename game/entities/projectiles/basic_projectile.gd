extends Node3D
class_name BasicProjectile

@export var speed: float = 12.0
@export var hit_distance: float = 0.25
@export var target_height_offset: float = 0.75

var damage: float = 0.0
var attacker: EntityBase = null
var target: EntityBase = null
var attacker_name := "Unknown attacker"
var target_name := "Unknown target"

func _ready() -> void:
	add_to_group(&"combat_projectiles")

func setup(source: EntityBase, target_entity: EntityBase, amount: float) -> void:
	attacker = source
	target = target_entity
	damage = amount
	if source != null and is_instance_valid(source):
		attacker_name = _get_entity_display_name(source)
	if target_entity != null and is_instance_valid(target_entity):
		target_name = _get_entity_display_name(target_entity)

func _process(delta: float) -> void:
	if not _has_valid_target():
		queue_free()
		return
	var target_pos := _get_target_position()
	var to_target := target_pos - global_position
	var distance := to_target.length()
	if distance <= hit_distance:
		_hit_target()
		return
	var step := minf(speed * delta, distance)
	global_position += to_target / distance * step

func _has_valid_target() -> bool:
	if attacker == null or not is_instance_valid(attacker):
		return false
	if target == null or not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
		return false
	if not target.can_be_attacked():
		return false
	return attacker.is_hostile_to(target)

func _hit_target() -> void:
	if not _has_valid_target():
		queue_free()
		return
	var health := target.get_health_component() as HealthComponent
	var max_health: float = health.max_health
	if not target.apply_damage(damage, attacker):
		queue_free()
		return
	var remaining_health: float = health.current_health
	if remaining_health > 0.0:
		print("%s projectile hit %s for %.1f damage. Remaining HP: %.1f/%.1f" % [
			attacker_name,
			target_name,
			damage,
			remaining_health,
			max_health,
		])
	else:
		print("%s projectile hit %s for %.1f damage. %s destroyed." % [
			attacker_name,
			target_name,
			damage,
			target_name,
		])
	queue_free()

func _get_target_position() -> Vector3:
	return target.global_position + Vector3.UP * target_height_offset

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name
