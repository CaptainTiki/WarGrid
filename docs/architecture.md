# WarGrid Architecture Principles

## Core Style

- Node-first architecture.
- Component-based programming.
- Prefer small, focused scripts.
- Avoid “one script does everything” design.
- Use inheritance only when it clearly makes sense, such as for shared behavior or array grouping.
- Save reusable things as scenes.
- Colocate scenes with their scripts.
- Use Godot groups for fast/global node lookup where appropriate.
- Explicitly type variants, but do not use := style. this can break godot if the variant is not known at runtime
- Do not create GUIDs for files, let GODOT build them. if you need to reference a file, use path, not GUID

## Authoring Rules

- Everything should be editor-authorable where possible.
- Reusable scenes should be saved as `.tscn`.
- Avoid generating nodes at runtime when those nodes could reasonably be authored/saved as scenes.
- Do not use runtime generation as a replacement for authoring reusable game objects.

## Approved Runtime Generation Exceptions

Terrain geometry generation is an approved exception.
Terrain meshes and terrain colliders may be generated from saved map data because the authored source of truth is the map resource itself.
This exception should not be used for units, buildings, UI, or reusable gameplay objects, which should be authored as scenes whenever practical.

## Collaboration Rule

- Ask before making architectural decisions.
- Do not assume missing requirements.
- When implementation requires a decision, stop and ask so efforts stay aligned.
