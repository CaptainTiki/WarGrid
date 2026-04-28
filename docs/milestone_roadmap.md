When we complete a target, lets remove from this list. when the list is empty we'll discuss and update

v14 - Command system
- Base UnitCommand
- CommandComponent
- MoveCommand
- StopCommand
- Infantry owns commands
- Input issues commands instead of direct movement

v15 - Minimal command UI/debug panel
- Show selected unit name
- Show command list
- Buttons for MOVE / STOP / ATTACK placeholder
- Hotkey support maybe

v16 - Second unit architecture test
- Add a heavier vehicle/scout unit
- Give it multiple TerrainFinders
- Confirm MovementComponent still behaves
- No fancy suspension yet

v17 - Movement/path prep
- Destination validation
- Optional line sampling between current position and target
- Block invalid direct routes
- Add path debug visualization

v18 - Actual pathfinding spike
- Cheap grid A*
- Uses terrain chunk walkability data
- MovementComponent consumes generated path
- Add "move toward" functionality - so that if you click on non-walkable,
  we move to the closest point to that non-walkable
