WarGrid Terrain Editor - Gameplay Data Overlay Milestone v0.3
Goal

Add authored gameplay data layers to the terrain map and provide toggleable overlay visualization for them.

This milestone is visualization/data-first. Painting tools for walkable/buildable/FOW can come after the data and overlay system are working.

Gameplay Data Layers

Add three gameplay data layers to the map data:

Walkable data
Buildable data
Fog-of-war height layer data

These should be stored as PackedByteArray.

Gameplay data applies only to the playable area, not the visual border.

Enums

Add terrain-owned enums that are easy to access from the terrain system.

Walkable enum:

ALL
AIR
NONE

Initial walkable overlay colors:

ALL = white
AIR = blue
NONE = black

Buildable enum:

OPEN
BLOCKED

Suggested buildable overlay colors:

OPEN = white or green
BLOCKED = black or red

FOW height layer should be stored as a byte/integer value.

Suggested starting FOW range:

0
1
2
3

FOW colors can be simple brightness or color bands for now.

Save / Load

Update save/load so the map resource includes:

walkable_data
buildable_data
fow_height_data

New maps should initialize playable cells to:

walkable = ALL
buildable = OPEN
fow_height = 0
Overlay Mesh

Add gameplay overlay visualization using duplicated chunk meshes.

For each terrain chunk:

Duplicate the terrain visual mesh for overlay display.
Offset the overlay vertices by approximately +0.01 along their normals.
Use a transparent overlay material.
Overlay alpha should be low, around 45 / 255.

The overlay should be visually separate from the main terrain material and should not complicate the terrain splat shader.

The implementation does not have to literally copy the existing mesh object if generating a separate overlay mesh from the same terrain data is cleaner. The requirement is that the overlay geometry matches the terrain and sits slightly above it.

Overlay Rebuild Timing

Overlay mesh duplication/rebuild should happen after sculpt brush strokes end for:

Raise/lower brush
Smooth brush
Flatten brush

Reason:

The overlay needs to match updated terrain shape, but it does not need to rebuild every brush frame.

During active sculpting, it is acceptable for the overlay to be temporarily stale.

Overlay Modes

Add UI controls:

A button/toggle to enable or disable overlay visuals.
A dropdown to choose which overlay is displayed.

Overlay modes:

None
Walkable
Buildable
FOW Height

Only one overlay mode needs to be displayed at a time for v0.3.

Overlay Coloring

Overlay colors should vary based on the selected data layer.

Walkable overlay:

ALL = white
AIR = blue
NONE = black

Buildable overlay:

OPEN = white or green
BLOCKED = black or red

FOW Height overlay:

Use visible color variations per height value.
Exact colors can be simple for now.
Coordinate Scope

Gameplay data covers only the playable area.

The overlay should only show gameplay data over playable terrain cells.

The visual border should not display walkable/buildable/FOW data.

Do Not Do Yet
Do not add gameplay data paint tools yet.
Do not build pathfinding.
Do not build units.
Do not build buildings.
Do not build fog-of-war runtime behavior.
Do not add runtime decals, tracks, or explosion effects.
Do not modify the main terrain splat shader for overlays.
