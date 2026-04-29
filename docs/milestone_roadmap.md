CURRENT RTS BUILD QUEUE

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

## v30.5 — 4-Chunk Test Map Foundation
Build a simple 4-chunk test map layout with:
- Player start area
- Enemy start area
- Enough distance between player units, player buildings, enemy dummy units, and enemy buildings
- Clear walkable paths
- Some blocked terrain or obstacles
- Room for testing movement, projectile combat, group commands, and future enemy AI

## v31 — Return to Map Editor: Entity Placement
Stop code-instantiating test units and buildings directly into the runtime map. The map editor should support deliberate scenario setup.

Add editor support for placing entities such as:
- Player units
- Player buildings
- Enemy units
- Enemy buildings
- Neutral objects later

## v32 — Map Runtime Entity Spawning
- Chunks load as they do now.
- Entity placement data is read from the map resource/data.
- Units and buildings are spawned at their editor-defined positions.
- Team IDs are applied correctly.
- Selection, command, combat, and scan systems work on spawned entities.


## v33 — Combat Sandbox Validation Map
- Player units start away from enemies.
- Player base/building starts in a safe location.
- Enemy Dummy Unit starts at a deliberate test location.
- Enemy Test HQ starts at a deliberate test location.
- Terrain provides enough room for movement and combat tests.



## v34 — Basic Unit Autonomy / Enemy Brain
- Enemy units can acquire nearby hostile targets.
- Enemy units can move toward valid targets.
- Enemy units can attack when appropriate.
- Player units may later auto-acquire or retaliate.
- Autonomy uses the existing team/faction and attack validation rules.

v35 - Production skeleton
- TestHQ Train Infantry actually queues/spawns infantry
- simple rally point stores position
- trained unit moves to rally point if set

v36 - Basic enemy brain
- enemy acquires target
- enemy moves/attacks using same command/movement systems
- keep it caveman simple

v37 - Resource/building placement spike
- build command
- placement ghost
- validate buildable terrain
- place simple building entity
