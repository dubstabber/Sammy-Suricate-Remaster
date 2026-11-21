extends RefCounted
class_name LevelBuilder

## Composes a playable level scene from converter output
## (`assets/levels/<stem>/<stem>.gltf` + `<stem>_entities.json`) and the
## level world template. Used by `tools/build_level_scenes.gd` to bake
## editor-editable scenes, and by tests.

const MapperScript := preload("res://src/levels/level_entity_mapper.gd")
const TEMPLATE_SCENE_PATH := "res://scenes/levels/level_world_template.tscn"
const LEVEL_ASSET_ROOT := "res://assets/levels"
const LEVEL_MANIFEST_PATH := "res://assets/levels/level_manifest.json"

const GEOMETRY_NODE := "Geometry"
const ENTITIES_NODE := "Entities"
const CONFIG_NODE := "Config"
const UNMAPPED_NODE := "Unmapped"
const SKY_GROUP := "Sky"
const PLAYER_START_NODE := "PlayerStart"
const LEVEL_10_NUMBER := 10
const LEVEL_10_STARTING_LIVES := 4


static func entities_path(stem: String) -> String:
	return "%s/%s/%s_entities.json" % [LEVEL_ASSET_ROOT, stem, stem]


static func load_level_data(stem: String) -> Dictionary:
	var path := entities_path(stem)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func converted_level_stems() -> PackedStringArray:
	var stems := PackedStringArray()
	if not FileAccess.file_exists(LEVEL_MANIFEST_PATH):
		return stems
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_MANIFEST_PATH))
	if parsed is Dictionary:
		for entry: Variant in (parsed as Dictionary).get("levels", []):
			if entry is Dictionary:
				stems.append(String((entry as Dictionary).get("stem", "")))
	return stems


## Returns {"root": Node3D, "report": Dictionary}, or {} when the level data is
## missing. The root is not inside the scene tree; every added node is owned by
## it so the result can be packed.
static func build(stem: String, level_number: int = 0) -> Dictionary:
	var data := load_level_data(stem)
	if data.is_empty():
		push_error("Level data missing for %s at %s" % [stem, entities_path(stem)])
		return {}
	var template := load(TEMPLATE_SCENE_PATH) as PackedScene
	# In the editor the baked scene inherits the template, so template changes
	# (environment, HUD, player wiring) reach every level without a re-bake.
	var template_state := PackedScene.GEN_EDIT_STATE_MAIN_INHERITED if OS.has_feature("editor") else PackedScene.GEN_EDIT_STATE_DISABLED
	var root := template.instantiate(template_state) as Node3D
	root.name = "Level_%s" % stem
	root.set("level_stem", stem)
	root.set("level_number", level_number)
	root.set("source_wmb", String(data.get("source", "")))

	var report := {
		"stem": stem,
		"mapped": {},
		"unmapped": {},
		"config": 0,
		"player_start": false,
		"score_goal": 0,
	}
	if not _add_geometry(root, data):
		root.free()
		return {}
	_configure_sun(root.get_node_or_null("Sun") as DirectionalLight3D, data.get("sun"))
	for entity: Variant in data.get("entities", []):
		if entity is Dictionary:
			_place_entity(root, entity as Dictionary, report)
	if level_number == LEVEL_10_NUMBER:
		# Loads.wdl InitLevel10 hard-codes BallesJoueur1 = 4.
		root.set("level_starting_lives", LEVEL_10_STARTING_LIVES)
	root.set_meta("wmb_light_count", (data.get("lights", []) as Array).size())
	root.set_meta("wmb_unmapped_actions", report["unmapped"])
	return {"root": root, "report": report}


static func _add_geometry(root: Node3D, data: Dictionary) -> bool:
	var geometry_data: Dictionary = data.get("geometry", {})
	var gltf_path := "res://" + String(geometry_data.get("gltf", ""))
	var geometry_scene := load(gltf_path) as PackedScene
	if geometry_scene == null:
		push_error("Level geometry missing at %s (run the import pass first)" % gltf_path)
		return false
	var geometry := geometry_scene.instantiate(MapperScript.instantiate_edit_state()) as Node3D
	geometry.name = "LevelGeometry"
	_add_owned(root, root.get_node(GEOMETRY_NODE), geometry)
	return true


## Acknex sun pan/tilt point from the scene towards the sun.
static func _configure_sun(sun: DirectionalLight3D, sun_data: Variant) -> void:
	if sun == null or not (sun_data is Dictionary):
		return
	var pan := deg_to_rad(float((sun_data as Dictionary).get("pan", 0.0)))
	var tilt := deg_to_rad(float((sun_data as Dictionary).get("tilt", 45.0)))
	var to_sun := Vector3(cos(tilt) * cos(pan), sin(tilt), -cos(tilt) * sin(pan)).normalized()
	var up := Vector3.UP if absf(to_sun.y) < 0.999 else Vector3.FORWARD
	sun.basis = Basis.looking_at(-to_sun, up)


static func _place_entity(root: Node3D, entity: Dictionary, report: Dictionary) -> void:
	var mapped := MapperScript.map_entity(entity)
	var kind: StringName = mapped.get("kind", MapperScript.KIND_UNMAPPED)
	var node := mapped.get("node") as Node3D
	match kind:
		MapperScript.KIND_PLAYER_START:
			var player_start := root.get_node_or_null(PLAYER_START_NODE) as Node3D
			if player_start != null:
				player_start.transform = mapped["player_transform"]
				report["player_start"] = true
			return
		MapperScript.KIND_SCORE_GOAL:
			root.set("score_goal_points", int(mapped.get("score_goal", 0)))
			root.set("score_start_points", int(mapped.get("score_start", 0)))
			report["score_goal"] = int(mapped.get("score_goal", 0))
			if node != null:
				_add_owned(root, root.get_node(CONFIG_NODE), node)
			report["config"] = int(report["config"]) + 1
			return
		MapperScript.KIND_CONFIG:
			_add_owned(root, root.get_node(CONFIG_NODE), node)
			report["config"] = int(report["config"]) + 1
			# mm1.wdl InitGame2: Skill1 is NbrBallesStart (0 keeps the previous value).
			if String(entity.get("action", "")) == "initgame2":
				var starting_lives := absi(int(_entity_skill(entity, 1)))
				if starting_lives > 0:
					root.set("level_starting_lives", starting_lives)
			return
		MapperScript.KIND_UNMAPPED:
			_add_owned(root, root.get_node(UNMAPPED_NODE), node)
			var unmapped: Dictionary = report["unmapped"]
			var action := String(entity.get("action", ""))
			unmapped[action] = int(unmapped.get(action, 0)) + 1
			return
		MapperScript.KIND_SKY:
			var sky_group := _ensure_group(root, root.get_node(ENTITIES_NODE), SKY_GROUP)
			_add_owned(root, sky_group, node)
			root.set("sky_path", root.get_path_to(sky_group))
			_count_mapped(report, StringName(SKY_GROUP))
			return
	var group := _ensure_group(root, root.get_node(ENTITIES_NODE), String(kind))
	_add_owned(root, group, node)
	var destination := mapped.get("destination") as Node3D
	if destination != null:
		_add_owned(root, group, destination)
		node.set("destination_path", node.get_path_to(destination))
	_count_mapped(report, kind)


static func _entity_skill(entity: Dictionary, skill_number: int) -> float:
	var skills: Array = entity.get("skills", [])
	return float(skills[skill_number - 1]) if skill_number >= 1 and skill_number <= skills.size() else 0.0


static func _count_mapped(report: Dictionary, kind: StringName) -> void:
	var mapped: Dictionary = report["mapped"]
	mapped[String(kind)] = int(mapped.get(String(kind), 0)) + 1


static func _ensure_group(root: Node3D, parent: Node, group_name: String) -> Node3D:
	var existing := parent.get_node_or_null(group_name) as Node3D
	if existing != null:
		return existing
	var group := Node3D.new()
	group.name = group_name
	_add_owned(root, parent, group)
	return group


## Adds `node` and assigns the level root as owner of it and of any
## code-created descendants (instanced prefab internals keep their own owner).
static func _add_owned(root: Node, parent: Node, node: Node) -> void:
	parent.add_child(node)
	_assign_owner(root, node)


static func _assign_owner(root: Node, node: Node) -> void:
	node.owner = root
	for child in node.get_children():
		if child.owner == null:
			_assign_owner(root, child)
