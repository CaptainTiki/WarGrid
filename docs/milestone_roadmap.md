CURRENT RTS BUILD QUEUE

v25 - Group movement v0
- For now, selected units can all receive the same move target/path
- Add simple destination spreading or small offsets so units do not stack perfectly
- No flocking yet unless easy
- Keep it predictable

v26 - Group anchor / flocking prototype
- GroupMoveController owns a path-following anchor
- Anchor moves at slowest selected unit speed
- Anchor cannot outrun the group beyond leash distance
- Units seek loose slots around anchor
- Separation keeps units apart
- Chokes naturally compress the group

v27 - Pathfinding hardening/debug
- path display
- destination marker
- nearest walkable target resolution
- failed move handling
- basic path smoothing maybe, but no fancy steering

v28 - Health + damage foundation
- HealthComponent
- DamageCommand or AttackComponent
- AttackCommand can target enemy entity
- placeholder damage application
- death/despawn or disabled state

v29 - Team/faction + target rules
- team_id matters
- can only attack enemies
- buildings/units know friend vs enemy
- command buttons can enable/disable based on target validity

v30 - Production skeleton
- TestHQ Train Infantry actually queues/spawns infantry
- simple rally point stores position
- trained unit moves to rally point if set

v31 - Enemy dummy / target practice
- add hostile test entity
- attack command can damage it
- no AI yet, just a valid target

v32 - Basic enemy brain
- enemy acquires target
- enemy moves/attacks using same command/movement systems
- keep it caveman simple

v33 - Resource/building placement spike
- build command
- placement ghost
- validate buildable terrain
- place simple building entity
