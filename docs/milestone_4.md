# WarGrid Runtime Unit Movement v0.1

## Goal

Add the first runtime unit test.

We want a generic infantry unit that can be selected with left click and moved with right click. The unit should use a reusable MovementComponent and TerrainFinder system so this movement approach can later support infantry, bikes, tanks, trucks, and other unit types.

This is not pathfinding yet. Movement should support a path array, but for now right-click movement can provide a single destination point.

---

## Architecture Rules

Follow the project architecture rules:

- Node-first architecture.
- Component-based programming.
- Reusable gameplay objects should be authored as scenes.
- Colocate scenes with their scripts.
- Keep scripts small and focused.
- Do not generate unit child nodes at runtime if they can be scene-authored.
- Ask rather than inventing new architecture.

Terrain mesh generation remains an approved exception, but unit scenes should be authored.

---

## Existing Terrain API

Use the terrain query API that already exists on Terrain:

- `get_height_at_local_position(local_position: Vector3) -> float`
- `get_visual_cell_from_local_position(local_position: Vector3) -> Vector2i`
- `get_playable_cell_from_local_position(local_position: Vector3) -> Vector2i`
- `get_walkable_at_local_position(local_position: Vector3) -> int`
- `is_ground_walkable_at_local_position(local_position: Vector3) -> bool`

Runtime game objects should ask Terrain questions through this API. Do not dig into TerrainMapData directly from unit scripts.

---

## New Scenes / Scripts

Create these as reusable authored scenes/scripts.

Suggested structure:

- `game/units/components/movement_component.tscn`
- `game/units/components/movement_component.gd`
- `game/units/components/terrain_finder.tscn`
- `game/units/components/terrain_finder.gd`
- `game/units/infantry/generic_infantry.tscn`
- `game/units/infantry/generic_infantry.gd`

If the existing project structure suggests a better location, follow the existing structure, but keep units/components organized and colocated.

---

## TerrainFinder

Create a TerrainFinder component.

TerrainFinder should be a scene-authored marker node.

Recommended:

- `TerrainFinder` extends `Marker3D`
- `class_name TerrainFinder`

For v0.1, TerrainFinder does not need complex behavior. It marks a terrain sample position under the movement component.

---

## MovementComponent

Create a reusable MovementComponent.

MovementComponent responsibilities:

- Own movement speed.
- Accept path points.
- Move the parent/root unit toward the current path point.
- Advance through path points.
- Sample terrain height while moving.
- Apply unit Y position from terrain height.
- Support one or more child TerrainFinder nodes.
- On `_ready()`, find child TerrainFinder nodes.
- Do not handle mouse input.
- Do not handle selection input.
- Do not perform pathfinding yet.

Expected methods:

- `set_terrain(terrain: Terrain) -> void`
- `set_path(points: Array[Vector3]) -> void`
- `clear_path() -> void`
- `has_path() -> bool`

For now, right-click movement will call `set_path([target_position])`.

---

## TerrainFinder Sampling Behavior

At `_ready()`, MovementComponent should gather child TerrainFinder nodes.

For v0.1, only one TerrainFinder is required for infantry.

Movement behavior for one finder:

- Move unit in X/Z toward the current target.
- Query terrain height at the unit/finder position.
- Set the unit/root Y position to the sampled terrain height.
- Keep the infantry upright.
- Rotate/yaw the unit to face movement direction.
- Do not pitch/roll infantry to match terrain yet.

The system should be designed so future vehicles can use multiple TerrainFinder nodes:

- 1 finder = infantry height sample
- 2 finders = future pitch support
- 4+ finders = future vehicle terrain plane support

But do not implement complex multi-finder pitch/roll yet unless it is simple and isolated.

---

## Generic Infantry Unit

Create a generic infantry scene.

Suggested scene shape:

- `GenericInfantry`
  - visible placeholder mesh, such as Capsule/MeshInstance3D
  - `MovementComponent`
	- `TerrainFinder`
  - selection visual, such as a ring or simple MeshInstance3D, initially hidden

Requirements:

- Unit is scene-authored.
- Unit has a simple visible body.
- Unit can be selected/deselected.
- Selection visual appears when selected.
- Unit uses MovementComponent for movement.

Suggested methods on infantry script:

- `set_selected(value: bool) -> void`
- `set_terrain(terrain: Terrain) -> void`
- `move_to(target_position: Vector3) -> void`

The infantry script can forward `move_to()` to MovementComponent.

---

## Game Selection / Command Input

Add a simple runtime input controller in the game/level scene.

Responsibilities:

- Left click selects the infantry unit.
- Right click commands the selected infantry to move.
- Right click should ray-pick the terrain using the existing terrain/camera picking flow.
- Before issuing move command, check `terrain.is_ground_walkable_at_local_position(...)`.
- If the clicked point is not ground-walkable, do not move the unit.
- For v0.1:
  - Walkable.ALL is valid for ground infantry.
  - Walkable.AIR is not valid for ground infantry.
  - Walkable.NONE is not valid for ground infantry.

Do not implement box selection yet.

Do not implement multi-select yet.

Do not implement command queues yet.

---

## Spawning

In the runtime game scene, spawn or place one GenericInfantry unit.

It should start on a valid playable/walkable point.

Preferred for v0.1:

- Add the GenericInfantry scene as an authored child of the Level scene if practical.
- If the map loads dynamically and scene-authored placement is awkward for now, instantiate the infantry scene from an exported PackedScene on the Level. This is acceptable for spawning gameplay objects, but the infantry scene itself must be authored.

Make sure the infantry receives a reference to Terrain.

---

## Click Picking

Use the existing terrain picking/raycast behavior if available.

Selection can be simple for v0.1:

- Infantry may have a simple clickable collision area/body.
- Left click raycasts against units first.
- If a unit is hit, select it.
- If terrain is hit, do not select anything unless desired.

Right click:

- Raycast terrain.
- Convert world/local position as needed.
- Check walkability.
- Send one-point path to selected infantry.

---

## Do Not Do Yet

- Do not build A* pathfinding yet.
- Do not build formations.
- Do not build multiple unit selection.
- Do not build attack commands.
- Do not build unit avoidance.
- Do not build animation systems.
- Do not build health/combat.
- Do not build buildings.
- Do not change the terrain editor tools.
- Do not modify the map save/load format unless required for this runtime test.

---

## Success Criteria

- Game mode loads the saved terrain map.
- One generic infantry unit appears on the terrain.
- Unit sits on the terrain height correctly.
- Left click selects the unit.
- Selection visual appears.
- Right click on Walkable.ALL terrain moves the selected unit.
- Right click on Walkable.AIR or Walkable.NONE terrain does not move the selected ground infantry.
- Unit follows terrain height while moving.
- Unit faces its movement direction.
- No pathfinding is required yet.
