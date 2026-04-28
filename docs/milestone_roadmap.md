CURRENT RTS BUILD QUEUE

v27 - Health + damage foundation
- HealthComponent
- DamageCommand or AttackComponent
- AttackCommand can target enemy entity
- placeholder damage application
- death/despawn or disabled state

v28 - Team/faction + target rules
- team_id matters
- can only attack enemies
- buildings/units know friend vs enemy
- command buttons can enable/disable based on target validity

v29 - Enemy dummy / target practice
- add hostile test entity
- attack command can damage it
- no AI yet, just a valid target

v30 - Production skeleton
- TestHQ Train Infantry actually queues/spawns infantry
- simple rally point stores position
- trained unit moves to rally point if set

v31 - Basic enemy brain
- enemy acquires target
- enemy moves/attacks using same command/movement systems
- keep it caveman simple

v32 - Resource/building placement spike
- build command
- placement ghost
- validate buildable terrain
- place simple building entity
