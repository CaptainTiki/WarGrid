CURRENT RTS BUILD QUEUE

v21 - Actual A* pathfinding spike
- Add cheap grid A*
- Use terrain chunk walkability data
- MoveCommand uses direct move if clear, A* if blocked
- MovementComponent consumes whole path
- Crude path debug drawing

v22 - Selection system refactor
- SelectionComponent becomes SelectionManager-style
- Track Array[EntityBase], not just one selected entity
- Single-click selects one entity
- Click empty ground clears selection
- Drag-select selects units only
- Buildings are click-selectable, but not drag-selected
- Shift-add/remove optional, maybe defer
- Selection changed signal sends full selected list

v23 - Common-command UI for multi-selection
- Command panel accepts selected_entities array
- Shows common commands shared by all selected entities
- Common means intersection by command_id
- If one Infantry + one ScoutBike selected: show Move / Stop / Attack
- If Infantry + TestHQ selected: likely show only commands they truly share, maybe none
- Button click dispatches command to all valid selected entities
- Targeting mode works with selected group

v24 - Multi-unit command dispatch
- Right-click terrain issues Move to all selected mobile units
- Stop stops all selected units with StopCommand
- Attack targeted command sends Attack to all selected attackers
- Buildings can still use their command UI when selected alone
- Mixed selections are safe and boring

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
