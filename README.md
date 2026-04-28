# Sammy Suricate Remaster

Godot 4.6 scaffold for reimplementing Sammy Suricate from the extracted Acknex/GameStudio A5 assets.

## Layout

- `assets/`: curated runtime asset slice copied from `extract-sammy-assets/`.
- `scenes/`: runnable Godot scenes, including `scenes/main.tscn`.
- `src/`: game systems, services, player control, camera, resources, and level metadata boundary.
- `tests/`: headless smoke tests for scaffold health.
- `extract-sammy-assets/`: source extraction workspace; keep this as evidence/source material, not runtime code.

Prototype music autoplay is disabled by default so headless validation exits cleanly.
Set `sammy/runtime/autoplay_music` to `true` when you want the prototype scene to start the copied OGG track automatically.
The project renders to a 1280x960 internal viewport and scales that image to the game window while preserving the 4:3 aspect ratio.

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
