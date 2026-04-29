# Sammy Suricate Remaster

Godot 4.6 scaffold for reimplementing Sammy Suricate from the extracted Acknex/GameStudio A5 assets.

## Layout

- `assets/`: curated runtime asset slice copied from `extract-sammy-assets/`.
- `scenes/`: runnable Godot scenes and editor-placeable prototype prefabs, including `scenes/main.tscn`.
- `src/`: game systems, services, player control, camera, reusable scene wiring, resources, and level metadata boundary.
- `tests/`: headless smoke tests for scaffold health.
- `extract-sammy-assets/`: source extraction workspace; keep this as evidence/source material, not runtime code.

Prototype music autoplay is disabled by default so headless validation exits cleanly.
Set `sammy/runtime/autoplay_music` to `true` when you want the prototype scene to start the copied OGG track automatically.
The project renders to a 1280x960 internal viewport and scales that image to the game window while preserving the 4:3 aspect ratio.
Prototype level objects are placed in the Godot scenes so designers can move, duplicate, or replace them in the editor without editing the world script.
Rasta and punk enemies are editor-placeable `CharacterBody3D` scenes with gravity seeded from the original `graviteEnnemy` and `AccgraviteEnnemy` WDL values.

## Controls

Normal gameplay controls are mapped from the original WDL scripts:

- Arrow keys: move forward/back and turn left/right.
- Ctrl / joy button 1: jump.
- Space / joy button 2: fire wasps; projectile spawning is still a placeholder until the weapon/ammo pass.
- Shift / joy button 3: boost.
- Alt / joy button 4: quick 180 degree turn.
- C: change camera mode.
- R: restart the current level.
- Esc, Enter, left mouse, and joy button 1 are reserved for menu cancel/confirm/accept flows.

## Validation

Run an import pass after copying new assets:

```bash
env HOME=/tmp/sammy-godot-home XDG_DATA_HOME=/tmp/sammy-godot-xdg /path/to/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --import
```

Run smoke tests:

```bash
env HOME=/tmp/sammy-godot-home XDG_DATA_HOME=/tmp/sammy-godot-xdg /path/to/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --script res://tests/test_runner.gd
```

Launch the configured main scene headlessly:

```bash
env HOME=/tmp/sammy-godot-home XDG_DATA_HOME=/tmp/sammy-godot-xdg /path/to/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --quit-after 2
```
# Sammy-Suricate-Remaster
