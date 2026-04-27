# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**WarGrid** is an RTS game built in Godot 4.6 focused on a foundational terrain system. The current milestone is developing an in-game map editor (Terrain Editor v0.1) for authoring and editing terrain before building gameplay systems on top.

The project prioritizes:
- Editor-authored maps over runtime generation
- Small, focused scripts over monolithic components
- Node-first, component-based architecture
- Terrain reliability for units, buildings, and camera interaction

## Architecture

### Terrain System (`/terrain`)

The terrain foundation implements a chunked heightmap system with these key concepts:

- **Dual Heightmaps**: Authored base heightmap (gameplay, walkability, buildability) + runtime deformation heightmap (visual cosmetic effects only)
- **Chunking**: 32m × 32m chunks, 1m cell resolution (prototype), 2 border chunks on each side for visual padding
- **Mesh & Collider Generation**: Built on-demand from authored heightmap data; colliders used for mouse picking, not physics
- **Profiling**: `TerrainProfiler` tracks performance; call `TerrainProfiler.flush_pending()` to log results
- **Dirty Chunk Updates**: Mark affected chunks for rebuild after terrain modifications

Core classes:
- `Terrain` — Main terrain node; manages chunks, queues, and dirty tracking; entry point for height brush application
- `TerrainChunk` — Individual chunk (Node3D) containing mesh instance, collision shape, and chunk data
- `TerrainMapData` — Authoritative terrain data (heightmaps, textures, gameplay arrays)
- `TerrainChunkData` — Per-chunk state (coord, dirty flag)
- `TerrainMeshBuilder` — Generates chunk mesh from heightmap and texture data
- `TerrainColliderBuilder` — Generates collision shape for mouse picking
- `TerrainBrushData` — Brush configuration (radius, strength, falloff)

### Map Editor (`/mapeditor`)

In-game editor for terrain authoring. Preferred over external editors because it uses the same renderer, camera, and input model as the game.

- `MapEditor` — Main editor node; wires tools, camera, preview, and UI together
- `HeightBrushTool` — First editing tool; raises/lowers terrain using falloff
- `BrushPreview` — Visual preview of brush footprint on terrain
- `EditorToolDock` — UI for tool selection and brush parameter adjustment

Tools receive `terrain` reference and apply changes via `terrain.apply_height_brush()`. Terrain queues affected chunks for rebuild.

### Camera & Input (`/system/camera`)

- `EditorCameraRig` — Manages camera position, rotation, and framing; supports `frame_point()` to focus on a location

### Game Foundation (`/game`)

Empty placeholder folders for future gameplay:
- `/buildings` — Building placement, visuals, mechanics (not yet built)
- `/units` — Unit placement, movement, grounding (not yet built)
- `/components` — Reusable gameplay components (not yet built)
- `/levels` — Level/map definitions (not yet built)

## Development Workflow

### Build & Run

No special build step required. Godot handles compilation.

- **Run** — Press F5 in Godot editor or from command line: `godot --play`
- **Main Scene** — `mapeditor/map_editor.tscn` (configured in project.godot)

### Debugging

- **Terrain Profiler** — Enabled by default. Check console output after `TerrainProfiler.flush_pending()` for mesh/collider build times
- **Debug Visualizations** — Terrain export var `debug_plain_gray` disables textures for mesh inspection
- **Dirty Chunk Tracking** — Terrain maintains `_mesh_rebuild_queue` and `_collider_rebuild_queue`; inspect in debugger during playback

### Common Tasks

**Add a new editor tool:**
1. Create new script extending from tool pattern (see `HeightBrushTool`)
2. Add tool class to `EditorToolDock.TOOL_*` constants
3. Wire tool signals and parameters in `MapEditor._ready()`
4. Implement tool logic to call `terrain.apply_*()` and queue chunk updates

**Modify terrain data:**
- Do NOT generate gameplay data (walkability, buildability) at runtime
- Changes to authored heightmap must mark affected chunks dirty via `terrain.queue_dirty_chunks()`
- For visual-only deformation, modify runtime heightmap and mark chunks dirty (deformation limit ~0.25m)

**Test terrain editing:**
- Brush preview shows footprint before applying
- Left-click raises; Shift+Left-click lowers
- Scroll wheel adjusts brush radius
- Editor UI (tool dock) controls brush strength and falloff

## Important Patterns

**Node Hierarchy**
- Terrain scene root contains chunk root, bounds visualization, and global state
- TerrainChunk is a Node3D with MeshInstance3D + StaticBody3D for picking
- Do NOT attach physics bodies to chunks for gameplay physics (colliders are picking-only)

**Chunk Keys**
- Terrain uses `_chunk_key(Vector2i)` to map chunk coordinates to internal dictionaries
- Always use chunk coordinates (Vector2i) in public APIs, keys internally

**Rebuild Queuing**
- Never call chunk rebuild directly; queue via `terrain.queue_dirty_chunks()`
- Queuing defers rebuilds to `_process()` to batch and spread work across frames
- Use `terrain.flush_rebuild_queues()` if immediate results needed (e.g., after bulk edits)

**Brush Strokes**
- Call `terrain.begin_height_brush_stroke()` before stroke; `finish_height_brush_stroke()` after
- During stroke, mesh rebuilds may use fast (non-pretty) normals; finish rebuilds with pretty normals
- Collider rebuilds can be deferred during stroke for performance

## Architectural Decisions to Ask About

Per `docs/architecture.md`, decisions requiring alignment:
- **Texture painting method** (direct color, material ID, splat map, or hybrid)
- **Final cell size** (currently 1m; needs testing)
- **Unit grounding sample count** (how many terrain points a unit samples for height/rotation)
- **Runtime deformation limits** (currently ~0.25m; to be tested)
- **Map save format** (single resource vs. level folder with multiple resources)

Before implementing features that touch these areas, verify approach with the team.

## Code Style

Per `docs/architecture.md`:
- Small, focused scripts; prefer composition over massive monoliths
- Use Godot groups for global node lookup
- Explicitly type variants but do NOT use `:=` syntax (breaks Godot runtime type inference)
- Do NOT create GUIDs for file references; use paths instead
- Reusable objects should be saved as scenes (`.tscn`), not generated at runtime
- Save authoring decisions in editor; avoid runtime generation of gameplay data
