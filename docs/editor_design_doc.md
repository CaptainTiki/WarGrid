# RTS Terrain System Intentions v0.1

## Purpose

This document captures the current design intentions for the RTS terrain system.

The goal is to avoid losing direction while developing the terrain foundation. This document should only include decisions and intentions that have been explicitly discussed and agreed on. Unresolved items should remain listed as open questions, not treated as final design.

---

# Core Direction

We are building an RTS terrain system before building the rest of the unit and gameplay systems on top of it.

The terrain system needs to support:

* Fully 3D-looking terrain.
* Hundreds of units on the board.
* Reliable unit grounding and movement.
* Reliable mouse picking with a movable/rotatable camera.
* Walkable and buildable map data.
* Fog-of-war height layers.
* Cosmetic terrain deformation.
* Editor-authored maps.
* An in-game map editor that may also become a player-facing level editor.

The terrain system should be designed around the constraints of the game, rather than relying on quick prototype math that could create floating, sinking, or jittering units.

---

# Terrain Data Model

## Two Heightmaps

The terrain uses two heightmaps:

1. **Authored Base Heightmap**
2. **Runtime Deformation Heightmap**

### Authored Base Heightmap

The authored base heightmap defines the designed terrain shape.

It is used for:

* Base terrain geometry generation.
* Gameplay terrain height.
* Walkability data.
* Buildability data.
* Fog-of-war height layers.
* Navigation data.
* Base terrain collider generation.
* Mouse ray picking support.

The authored base heightmap does not change during normal gameplay.

### Runtime Deformation Heightmap

The runtime deformation heightmap stores cosmetic terrain deformation.

It may be used for:

* Explosion divots.
* Building visual smoothing or flattening.
* Tank track impressions.
* Cosmetic terrain wear.

Runtime deformation is visual only and does not alter navigation, walkability, buildability, or fog-of-war gameplay data.

### Combined Visual Height

The visual terrain height is calculated from:

```text
visual_height = authored_base_height + runtime_deformation_height
```

Units may query the combined/deformed height for visual grounding and tilt.

Buildings use the base heightmap for placement checks, then may apply a visual smoothing operation to the runtime deformation heightmap.

---

# Terrain Texture / Paint Data

## Two Texture Maps

The terrain uses two texture/paint layers:

1. **Authored Base Texture Map**
2. **Runtime Texture Map**

### Authored Base Texture Map

The authored base texture map defines the designed terrain appearance.

It may represent grass, dirt, rock, road, or other terrain colors/materials.

### Runtime Texture Map

The runtime texture map stores cosmetic battle and gameplay marks.

It may be used for:

* Scorch marks.
* Tank tracks.
* Explosion stains.
* Construction marks.
* Other temporary or runtime visual effects.

### Combined Terrain Color

The final terrain appearance comes from blending the authored base texture map with the runtime texture map.

The exact texture painting method is not finalized yet.

---

# Gameplay Data Arrays

The terrain has separate gameplay data arrays.

These are authored and saved with the map data. They should not be generated at runtime during normal gameplay.

Known gameplay data arrays:

* Walkable data.
* Buildable data.
* Fog-of-war height layer data.

These arrays define how the game plays on the map.

Runtime cosmetic terrain deformation does not change these gameplay arrays.

---

# Collider Usage

The terrain should have a collider for mouse ray picking.

The collider is based on the authored base terrain, not the runtime deformation layer.

The collider is used for:

* Reliable mouse picking.
* Cursor placement.
* Editor brush placement.
* Interacting with the terrain using a movable/rotatable camera.

The collider does not need to be rebuilt for runtime cosmetic deformation.

---

# Unit Grounding and Rotation

Units should not rely on gravity and full physics simulation as the primary method of staying grounded.

Units should query the terrain height data.

For visual grounding, units may sample:

```text
authored_base_height + runtime_deformation_height
```

Vehicle-style units may sample multiple contact points around their footprint to determine height and rotation.

The exact number of samples has not been finalized.

---

# Building Placement and Smoothing

Buildings should use the authored base heightmap and gameplay data arrays for placement validation.

Building placement should check against authored gameplay rules, not runtime cosmetic deformation.

After a building is placed, it may apply cosmetic smoothing or flattening to the runtime deformation heightmap.

This smoothing is visual only and does not alter navigation, walkability, buildability, or fog-of-war data.

---

# Runtime Visual Deformation

Runtime terrain deformation is cosmetic only.

Examples include:

* Small explosion divots.
* Building smoothing.
* Tank tracks.
* Brush marks from unit movement.

The current intention is that runtime deformation should remain small and should not alter gameplay.

A possible maximum deformation amount discussed was approximately `0.25m`, but this value should be treated as a prototype constraint until tested.

---

# Chunking

Terrain is chunked.

Current chunk design:

```text
chunk_size = 32m x 32m
cell_size = 1m for the prototype
```

A maximum playable map size discussed:

```text
playable_area = 512m x 512m
```

At 32m chunks, this means:

```text
16 x 16 playable chunks
```

The terrain also includes a visual-only border:

```text
visual_border = 64m on each side, currently represented as 2 border chunks
```

So a 512m x 512m playable area would have a total visual terrain area of:

```text
640m x 640m
```

The visual border has no gameplay data, no navigation, and no required collider.

---

# Dirty Chunk Updates

Runtime cosmetic changes mark affected chunks as dirty.

Examples of dirtying operations:

* Explosion deformation.
* Building smoothing.
* Runtime texture marks.
* Tank track or brush marks.

Dirty chunks can then be regenerated.

If a change touches a chunk border, neighboring chunks may need to be checked or updated so borders remain visually consistent.

Dirty chunk updates affect visual terrain only.

They do not update:

* Walkability.
* Buildability.
* Fog-of-war height layers.
* Navigation data.
* Gameplay terrain rules.

---

# Map Size and Resolution

The prototype should start with:

```text
cell_size = 1m
chunk_size = 32m
```

The cell size is not considered final.

The plan is to prototype with 1m resolution, observe how it feels, then decide whether to keep it or change it.

---

# Map Authoring Direction

We intend to build an in-game map editor.

The in-game editor is preferred because:

* It uses the same terrain renderer as the game.
* It uses the same camera and input style as the game.
* It can test unit movement and pathing directly.
* It can test building placement and visual smoothing directly.
* It produces the same saved map data the game will load.
* It may be included in the game jam build as a level editor if the project develops well.

The editor should save all data needed to play a game on the map.

It is acceptable for a level folder to contain several resources that together define the map.

---

# Initial Terrain Editor Toolset

The first editor milestone should be simple.

## New Map Creation

The editor should create a new flat map.

Initial map creation should support:

* Width in chunks.
* Length in chunks.
* Fixed 32m chunk size.
* Fixed 64m visual border on all sides, represented as 2 border chunks.
* Default terrain height.
* Default terrain material, such as grass.

The editor should support small test maps first, such as:

```text
2 x 2 playable chunks
2 chunk visual border on each side
6 x 6 total generated chunks
```

And eventually allow maps up to:

```text
8 x 8 playable chunks
```

## First Tool: Height Brush

The first map editing tool should be a height brush.

The height brush should support:

* Adjustable brush size.
* Adjustable brush amount or strength.
* Visible brush preview on the terrain.
* Click-and-drag editing.
* Rebuilding affected chunks after changes.

The first brush should allow the user to raise or lower the authored base heightmap.

---

# Editor Visualization

The editor should eventually support visualization toggles.

Known visualization needs:

* Normal terrain mesh view.
* Walkable cells.
* Buildable cells.
* Fog-of-war height layers.
* Chunk boundaries.
* Playable area boundaries.
* Visual border boundaries.
* Brush preview.

---

# Editor Test Mode

The editor should eventually include a test mode.

Test mode may allow:

* Placing a unit.
* Moving a unit around the terrain.
* Testing pathing.
* Placing buildings.
* Testing building smoothing.
* Testing explosion deformation.

This is intended to validate whether the terrain system works before building the rest of the RTS gameplay on top of it.

---

# Project Folder Direction

Terrain should remain a top-level project folder:

```text
/terrain
```

The terrain system is shared infrastructure used by both the in-game map editor and the game runtime.

The map editor should own editor interaction, tools, UI, brush input, and save/load flow.

The terrain folder should own terrain data, chunk generation, mesh/collider generation, terrain queries, and shared terrain logic.

---

# Runtime Generation Policy

The game should not generate authored gameplay data at runtime.

The saved map should already contain the data needed to play the game.

Runtime may generate:

* Actual terrain geometry from the saved heightmaps and maps.
* Visual chunks.
* Runtime deformation effects.
* Runtime texture effects.

Runtime should not generate the authored gameplay rules for the map during normal play.

---

# Open Questions

These are not finalized yet.

## Texture Painting Method

We still need to decide how the authored base texture map and runtime texture map should work.

Possible approaches include:

* Direct color map.
* Material ID map.
* Splat map.
* Some hybrid of these.

This is the next major design discussion point.

## Final Cell Size

The prototype starts at 1m resolution.

Final cell size will be decided after testing terrain editing, unit movement, building placement, and visual deformation.

## Unit Grounding Sample Count

We have not finalized how many terrain samples a unit should use for grounding and rotation.

Vehicle-style units may use multiple samples around their footprint.

## Exact Runtime Deformation Limits

A small limit such as `0.25m` has been discussed, but the exact value should be tested.

## Save Format

The map may save as one resource or as several resources in a level folder.

The exact file layout is not finalized yet.

---

# Current First Milestone

The current first milestone is:

```text
Terrain Editor v0.1
```

Minimum target:

* Create a flat grass map.
* Choose map width and length in 32m chunks.
* Automatically include a 64m visual border on all sides.
* Generate terrain mesh chunks from saved height/material data.
* Show the terrain in an in-game editor scene.
* Support mouse picking on the terrain.
* Show a visible brush preview.
* Use a height brush to raise/lower terrain.
* Rebuild affected chunks after editing.

This milestone proves whether the terrain data, mesh generation, chunking, mouse picking, and first authoring tool are working together.
