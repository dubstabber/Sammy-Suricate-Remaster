extends SceneTree

## Bakes converted WMB levels into Godot scenes.
##
## Usage (after tools/convert_level_wmb.py and an import pass):
##   godot --headless --path . --script res://tools/build_level_scenes.gd -- 10001 101o_j
##   godot --headless --path . --script res://tools/build_level_scenes.gd -- --all
##
## Writes scenes/levels/generated/<stem>.tscn on every run (re-bake after
## changing the level template or mapper), and creates the editable
## scenes/levels/<stem>.tscn (inheriting the generated one) only when it does
## not exist yet, so hand edits survive re-bakes.

const LevelBuilderScript := preload("res://src/levels/level_builder.gd")
const MenuLevelCatalogScript := preload("res://src/menu/menu_level_catalog.gd")
const GENERATED_DIR := "res://scenes/levels/generated"
const LEVEL_SCENE_DIR := "res://scenes/levels"


func _init() -> void:
	var stems := _requested_stems()
	if stems.is_empty():
		push_error("No level stems given. Pass stems after `--`, or `--all`.")
		quit(1)
		return
	var failures := 0
	for stem in stems:
		if _bake(stem) != OK:
			failures += 1
	print("baked %d/%d levels" % [stems.size() - failures, stems.size()])
	quit(1 if failures > 0 else 0)


func _requested_stems() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	if args.has("--all"):
		return LevelBuilderScript.converted_level_stems()
	var stems := PackedStringArray()
	for arg in args:
		if not arg.begins_with("--"):
			stems.append(arg.to_lower())
	return stems


func _bake(stem: String) -> Error:
	var level_number := MenuLevelCatalogScript.level_number_for_stem(stem)
	var result := LevelBuilderScript.build(stem, level_number)
	if result.is_empty():
		return ERR_CANT_CREATE
	var root := result["root"] as Node3D
	var root_name := String(root.name)
	var report: Dictionary = result["report"]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIR))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		push_error("Unable to pack level %s: %s" % [stem, error_string(err)])
		return err
	var generated_path := "%s/%s.tscn" % [GENERATED_DIR, stem]
	err = ResourceSaver.save(packed, generated_path)
	if err != OK:
		push_error("Unable to save %s: %s" % [generated_path, error_string(err)])
		return err

	var editable_path := "%s/%s.tscn" % [LEVEL_SCENE_DIR, stem]
	if not FileAccess.file_exists(editable_path):
		err = _create_inherited_scene(generated_path, editable_path, root_name)
		if err != OK:
			return err

	var unmapped: Dictionary = report["unmapped"]
	if not unmapped.is_empty():
		push_warning("%s: unmapped WMB actions %s" % [stem, JSON.stringify(unmapped)])
	print("%s: mapped %s, config %d, unmapped %d, score goal %d, player start %s" % [
		stem,
		JSON.stringify(report["mapped"]),
		int(report["config"]),
		_sum_values(unmapped),
		int(report["score_goal"]),
		str(report["player_start"]),
	])
	return OK


## Scripts cannot mark a packed root as inherited, so write the (tiny) inherited
## scene text directly, exactly as the editor's "New Inherited Scene" saves it.
func _create_inherited_scene(base_path: String, editable_path: String, root_name: String) -> Error:
	var file := FileAccess.open(editable_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s: %s" % [editable_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string("[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_generated\"]\n\n[node name=\"%s\" instance=ExtResource(\"1_generated\")]\n" % [base_path, root_name])
	file.close()
	return OK


func _sum_values(values: Dictionary) -> int:
	var total := 0
	for value: Variant in values.values():
		total += int(value)
	return total
