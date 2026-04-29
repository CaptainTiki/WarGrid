# WarGrid Roadmap Update — Pre-AI Map / Editor Foundation

## Current Status

### v30 — Hostile Dummy Unit
**Status:** Functionally complete, but not fully map-tested yet.

Confirmed behavior:

- Enemy Dummy Unit exists.
- Enemy Dummy Unit is team enemy.
- Enemy Dummy Unit is selectable as scan-only.
- Enemy Dummy Unit cannot be commanded by the player.
- Player units can attack the Enemy Dummy Unit.
- Enemy Dummy Unit takes projectile damage.
- Enemy Dummy Unit dies and cleans up correctly.
- Enemy Test HQ group attack still works.
- Ownership-gated command dispatch is working.
- Stop cancels future attack firing.
- Already-launched projectiles may still land, which is acceptable.

## Roadmap Adjustment

We are pushing **v31+ enemy brain/autonomy work** back until the map/editor foundation is stronger.

Reason:

Right now test entities are too close together and are still being instantiated directly by code. If we add enemy brains or unit autonomy now, combat may begin immediately on map load, creating messy and misleading test behavior.

The editor and map setup should own scenario placement. Code should own runtime behavior.

---

# New Pre-AI Roadmap

## v30.5 — 4-Chunk Test Map Foundation

### Goal

Create a larger deliberate combat and movement test arena before adding unit autonomy.

### Scope

Build a simple 4-chunk test map layout with:

- Player start area
- Enemy start area
- Enough distance between player units, player buildings, enemy dummy units, and enemy buildings
- Clear walkable paths
- Some blocked terrain or obstacles
- Room for testing movement, projectile combat, group commands, and future enemy AI

### Acceptance Tests

- Map loads correctly.
- All 4 chunks appear in the expected layout.
- Terrain walking still works.
- Group movement still works across chunk boundaries.
- No combat begins automatically on map load.
- The map gives enough space to deliberately test attacks.

---

## v31 — Return to Map Editor: Entity Placement

### Goal

Stop code-instantiating test units and buildings directly into the runtime map. The map editor should support deliberate scenario setup.

### Scope

Add editor support for placing entities such as:

- Player units
- Player buildings
- Enemy units
- Enemy buildings
- Neutral objects later

Each placed entity should store enough data to be recreated at runtime.

Suggested placement data:

- Scene or resource path
- Position
- Rotation
- Team ID
- Optional display name
- Optional prototype tag or entity type ID

### Design Rule

The editor owns scenario setup.

Runtime should load what the editor saved instead of manually spawning test objects from code.

### Acceptance Tests

- The editor can place at least one player unit.
- The editor can place at least one player building.
- The editor can place at least one enemy unit.
- The editor can place at least one enemy building.
- Placement data is saved into the map data.
- Reopening the map preserves placed entities.
- Existing chunk editing behavior is not broken.

---

## v32 — Map Runtime Entity Spawning

### Goal

Runtime map loading should spawn placed entities from map data.

### Scope

When the map loads:

- Chunks load as they do now.
- Entity placement data is read from the map resource/data.
- Units and buildings are spawned at their editor-defined positions.
- Team IDs are applied correctly.
- Selection, command, combat, and scan systems work on spawned entities.

### Acceptance Tests

- Player units spawn from map data.
- Player buildings spawn from map data.
- Enemy dummy units spawn from map data.
- Enemy buildings spawn from map data.
- Team ownership is correct after spawn.
- Enemy objects are selectable as scan targets.
- Enemy objects are not commandable.
- Player-owned units remain commandable.
- Group movement still works.
- Group attack still works.
- Sustained projectile combat still works.

---

## v33 — Combat Sandbox Validation Map

### Goal

Use the 4-chunk test map as a stable combat sandbox before adding AI/autonomy.

### Scope

Create a deliberate test scenario:

- Player units start away from enemies.
- Player base/building starts in a safe location.
- Enemy Dummy Unit starts at a deliberate test location.
- Enemy Test HQ starts at a deliberate test location.
- Terrain provides enough room for movement and combat tests.

### Acceptance Tests

- No instant combat occurs on map load.
- Player can select units and move them toward enemies.
- Player can scan enemy units/buildings.
- Player can attack Enemy Dummy Unit.
- Player can attack Enemy Test HQ.
- Enemy targets take projectile damage and die correctly.
- Stop cancels attacks.
- Move cancels attacks.
- Ownership-gated command panel still works.
- Mixed selection behavior still works.
- No invalid target or queue_free errors occur.

---

## v34 — Basic Unit Autonomy / Enemy Brain

### Goal

Only after the map/editor foundation is stable, begin adding basic unit autonomy.

### Early Scope

Add simple default behavior such as:

- Enemy units can acquire nearby hostile targets.
- Enemy units can move toward valid targets.
- Enemy units can attack when appropriate.
- Player units may later auto-acquire or retaliate.
- Autonomy uses the existing team/faction and attack validation rules.

### Important Constraint

Do not build this until the larger test map and editor-driven entity placement are working.

### Acceptance Tests

To be defined after v30.5 through v33 are complete.

---

# Guiding Principle

**Map editor owns setup. Runtime systems own behavior.**

This avoids chaotic code-spawned test scenes and gives us a cleaner foundation for enemy brains, unit autonomy, production, rally points, resources, and future RTS gameplay systems.
