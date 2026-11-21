extends RefCounted
class_name LevelEntityMapper

## Maps decoded WMB4 entity records (see tools/convert_level_wmb.py) onto the
## project's prefab scenes. Placement and skill meanings follow the original
## WDL Init* actions; anything without a prefab becomes a LevelEntityMarker.

const AcknexCoordsScript := preload("res://src/levels/acknex_coords.gd")
const LevelEntityMarkerScript := preload("res://src/levels/level_entity_marker.gd")
const ModelPropScript := preload("res://src/props/model_prop.gd")
const LevelStaticPropScript := preload("res://src/props/level_static_prop.gd")
const AssetsScript := preload("res://src/core/assets.gd")
const KeyRules := preload("res://src/resources/key_diamond_rules.gd")

const DIAMOND_SCENE := preload("res://scenes/pickups/diamond_pickup.tscn")
const KEY_DIAMOND_SCENE := preload("res://scenes/pickups/key_diamond_pickup.tscn")
const WASP_PICKUP_SCENE := preload("res://scenes/pickups/wasp_pickup.tscn")
const BOOST_SCENE := preload("res://scenes/pickups/boost_pickup.tscn")
const SMALL_HEART_SCENE := preload("res://scenes/pickups/small_heart_pickup.tscn")
const LIFE_HEART_SCENE := preload("res://scenes/pickups/life_heart_pickup.tscn")
const EYE_OF_TRUTH_SCENE := preload("res://scenes/pickups/eye_of_truth_pickup.tscn")
const KEY_GATE_SCENE := preload("res://scenes/gates/key_gate.tscn")
const EXIT_PAD_SCENE := preload("res://scenes/props/exit_pad.tscn")
const DEATH_PAD_SCENE := preload("res://scenes/props/death_pad.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/props/checkpoint.tscn")
const TELEPORTER_SCENE := preload("res://scenes/props/teleporter.tscn")
const GEM_SPAWNER_SCENE := preload("res://scenes/spawners/gem_spawner.tscn")
const WASP_SPAWNER_SCENE := preload("res://scenes/spawners/wasp_spawner.tscn")
const CACTUS_SCENE := preload("res://scenes/props/cactus_prop.tscn")
const LEVEL_SPRITE_SCENE := preload("res://scenes/props/level_sprite.tscn")
const RASTA_SCENE := preload("res://scenes/enemies/rasta_enemy.tscn")
const PUNK_SCENE := preload("res://scenes/enemies/punk_enemy.tscn")
const SCORPION_SCENE := preload("res://scenes/enemies/scorpion_enemy.tscn")
const NANOLION_SCENE := preload("res://scenes/enemies/nanolion_enemy.tscn")
const ROCKER_SCENE := preload("res://scenes/enemies/rocker_enemy.tscn")
const HIPPIE_SCENE := preload("res://scenes/enemies/hippie_enemy.tscn")

const SPRITE_TEXTURE_ROOT := "res://assets/textures/sprites"
const WASP_TYPE_PATH_FORMAT := "res://assets/wasps/type_%d.tres"
const MAX_WASP_TYPE := 7
const DEFAULT_DIAMOND_FILE := "gemgr+17.pcx"

const KIND_PLAYER_START := &"player_start"
const KIND_SCORE_GOAL := &"score_goal"
const KIND_CONFIG := &"config"
const KIND_UNMAPPED := &"unmapped"
const KIND_SKY := &"sky"

## Invisible level-config entities kept as markers for later milestones.
const CONFIG_ACTIONS := [
	"initgame2", "initgame3", "initgame4", "initgame5", "initgame6", "initgame7", "initgame8",
	"initcamera1", "initcamera2", "initcamera3", "initcamera4", "setcamera",
	"initpath", "initlionskills1", "initlionskills2", "initextraballes", "initnextraballes",
	"initpublic", "initprotection", "initstartennemy",
]

## Enemy model file -> prefab. An unknown model falls back to the rasta
## controller and keeps a `placeholder_for` meta.
const ENEMY_SCENES_BY_FILE := {
	"rasta.mdl": RASTA_SCENE,
	"punk.mdl": PUNK_SCENE,
	"scorpion.mdl": SCORPION_SCENE,
	"nanolion.mdl": NANOLION_SCENE,
	"rockera.mdl": ROCKER_SCENE,
	"hippie.mdl": HIPPIE_SCENE,
}

const TELEPORT_MODEL_IDS_BY_FILE := {
	"teleport.wmb": "model.teleport.pad",
	"telelion.wmb": "model.teleport.lion",
}
# teleport.wmb / telelion.wmb / tiledeat.wmb pad height in quants.
const WMB_PAD_HEIGHT := 32.0

const MODEL_ASSET_IDS_BY_FILE := {
	"sky2.mdl": "model.sky2",
	"sky3.mdl": "model.sky3",
	"sky4.mdl": "model.sky4",
	"sky5.mdl": "model.sky5",
	"solmenu4.mdl": "model.solmenu4",
	"solmenu5.mdl": "model.menu.floor",
	"bigtree1.mdl": "model.bigtree1",
	"greenhi1.mdl": "model.greenhi1",
	"grate1.mdl": "model.grate1",
	"huttop2.mdl": "model.huttop2",
}
## Backdrop models (skies, distant floors/hills) never collide.
const DECOR_MODEL_FILES := ["sky2.mdl", "sky3.mdl", "sky4.mdl", "sky5.mdl", "solmenu4.mdl", "solmenu5.mdl", "bigtree1.mdl", "greenhi1.mdl"]
## Converted brush WMB families searched for action-less static brush entities.
const BRUSH_MODEL_FAMILY_DIRS := [
	"res://assets/models/level_props",
	"res://assets/models/spawners",
	"res://assets/models/gates",
	"res://assets/models/platforms",
]

# WDL HeightGem (quants) used by InitBonus3/InitKey/InitSmallHeart sonar snaps.
const WDL_HEIGHT_GEM := 25.0
# WDL lion speed: SpeedEnnemy units/tick at 16 ticks/s and 0.01 m/quant.
const WDL_SPEED_UNIT_TO_METERS_PER_SECOND := 0.16
const WDL_DEFAULT_LION_ATTACK_RANGE := 500.0
## lion.wdl LionForce: BounceForce when Frc(SpeedEnnemy) is 0.
const WDL_LION_FORCE := 1.5
## lion.wdl InitLion: Int(IdEnnemy) -> [IdEnnemySpec, WeightForce, default
## EnnemyResistance]. The id, not the model file, picks the family stats.
const WDL_LION_FAMILIES := {
	10: [1.0, 0.65, 6.0], # nanolion
	0: [1.0, 0.62, 9.0], # rasta
	11: [1.0, 0.62, 9.0], # rasta
	1: [2.0, 0.3, 100.0], # elephant (unused by shipped levels)
	2: [3.0, 0.75, 12.0], # scorpion
	3: [3.0, 0.75, 12.0], # scorpion, second skin
	12: [1.0, 0.6, 12.0], # hippie
	13: [1.0, 0.55, 15.0], # rocker
	14: [1.0, 0.5, 30.0], # punk
}
const WDL_DOOR_MIN_OPEN_HEIGHT := 300.0
const WDL_DOOR_OPEN_HEIGHT_THRESHOLD := 250.0
const WDL_SKY_DEFAULT_SCALE_XY := 5.0
const WDL_SKY_DEFAULT_SCALE_Z := 3.0
const WDL_SKY_BASE_Z := -3300.0
const WDL_DECOR_DEFAULT_Z := -500.0
const WDL_DECOR_DEFAULT_SCALE_XY := 1.75
const WDL_DECOR_DEFAULT_SCALE_Z := 1.5


## Returns a dictionary describing how to place the entity:
## - kind: StringName group (Entities/<Kind>) or one of the KIND_* constants
## - node: Node3D to add (null for player_start/score_goal)
## - player_transform / score_goal / score_start / destination as needed
static func map_entity(entity: Dictionary) -> Dictionary:
	var action := String(entity.get("action", ""))
	match action:
		"initmarche":
			return {"kind": KIND_PLAYER_START, "player_transform": _character_transform(entity)}
		"initgame":
			return {
				"kind": KIND_SCORE_GOAL,
				"score_goal": int(_skill(entity, 7)),
				"score_start": int(_skill(entity, 8)),
				"node": _make_marker(entity),
			}
		"initbonus3":
			return {"kind": &"Pickups", "node": _make_diamond(entity)}
		"initkey":
			return {"kind": &"Pickups", "node": _make_key_diamond(entity)}
		"initammo1":
			return {"kind": &"Pickups", "node": _make_wasp_pickup(entity)}
		"initboost":
			return {"kind": &"Pickups", "node": _instantiate(BOOST_SCENE, entity, _prop_transform(entity))}
		"initbonusvie":
			return {"kind": &"Pickups", "node": _instantiate(LIFE_HEART_SCENE, entity, _prop_transform(entity))}
		"initsmallheart":
			return {"kind": &"Pickups", "node": _instantiate(SMALL_HEART_SCENE, entity, _gem_snapped_transform(entity))}
		"initeyeoftruth":
			return {"kind": &"Pickups", "node": _instantiate(EYE_OF_TRUTH_SCENE, entity, _gem_snapped_transform(entity))}
		"initdoor", "initdoorweak":
			return {"kind": &"Gates", "node": _make_gate(entity, action == "initdoorweak")}
		"initexit":
			return {"kind": &"Pads", "node": _instantiate(EXIT_PAD_SCENE, entity, _prop_transform(entity))}
		"inittiledeath":
			return {"kind": &"Pads", "node": _instantiate(DEATH_PAD_SCENE, entity, _prop_transform(entity))}
		"initrestart":
			return {"kind": &"Checkpoints", "node": _instantiate(CHECKPOINT_SCENE, entity, _prop_transform(entity))}
		"initteleport":
			return _make_teleporter(entity)
		"initboulder":
			return {"kind": &"Spawners", "node": _make_spawner(GEM_SPAWNER_SCENE, entity)}
		"inithive":
			return {"kind": &"Spawners", "node": _make_spawner(WASP_SPAWNER_SCENE, entity)}
		"initlion":
			return {"kind": &"Enemies", "node": _make_enemy(entity)}
		"initarbre", "onground":
			var sprite := _make_sprite(entity, action)
			if sprite != null:
				return {"kind": &"Sprites", "node": sprite}
		"initmdl":
			if _file(entity) == "cactus1.mdl":
				return {"kind": &"Props", "node": _instantiate(CACTUS_SCENE, entity, _prop_transform(entity))}
			var model_static := _make_init_mdl_prop(entity)
			if model_static != null:
				return {"kind": &"Statics", "node": model_static}
		"":
			if _file(entity).ends_with(".pcx"):
				var placed_sprite := _make_sprite(entity, "")
				if placed_sprite != null:
					return {"kind": &"Sprites", "node": placed_sprite}
			var static_prop := _make_actionless_static(entity)
			if static_prop != null:
				return {"kind": &"Statics", "node": static_prop}
		"initdecor":
			var decor := _make_model_prop(entity, _decor_transform(entity))
			if decor != null:
				return {"kind": &"Props", "node": decor}
		"initskymenu":
			var sky := _make_model_prop(entity, _sky_transform(entity))
			if sky != null:
				return {"kind": KIND_SKY, "node": sky}
	if CONFIG_ACTIONS.has(action):
		return {"kind": KIND_CONFIG, "node": _make_marker(entity)}
	return {"kind": KIND_UNMAPPED, "node": _make_marker(entity)}


static func node_name_for(entity: Dictionary) -> String:
	var action := String(entity.get("action", ""))
	if action.is_empty():
		action = "static_" + _file(entity).get_basename()
	return "E%03d_%s" % [int(entity.get("index", 0)), action.validate_node_name()]


# --- entity accessors ---------------------------------------------------------


static func _skill(entity: Dictionary, skill_number: int) -> float:
	var skills: Array = entity.get("skills", [])
	var index := skill_number - 1
	return float(skills[index]) if index >= 0 and index < skills.size() else 0.0


static func _flag(entity: Dictionary, flag_number: int) -> bool:
	return (int(entity.get("flags", 0)) & (1 << (flag_number - 1))) != 0


static func _file(entity: Dictionary) -> String:
	return String(entity.get("file", "")).to_lower()


static func _pan(entity: Dictionary) -> float:
	return AcknexCoordsScript.array_to_vector3(entity.get("angles", [])).x


static func _acknex_position(entity: Dictionary) -> Vector3:
	return AcknexCoordsScript.array_to_vector3(entity.get("position", []))


static func _acknex_scale(entity: Dictionary) -> Vector3:
	return AcknexCoordsScript.array_to_vector3(entity.get("scale", []), Vector3.ONE)


static func _godot_position(entity: Dictionary) -> Vector3:
	return AcknexCoordsScript.to_godot_position(_acknex_position(entity))


static func _has_ground(entity: Dictionary) -> bool:
	return entity.get("ground_z") != null


static func _ground_z(entity: Dictionary) -> float:
	return float(entity.get("ground_z")) if _has_ground(entity) else _acknex_position(entity).z


## Godot position whose y is the traced ground plus `height_above_ground` quants.
static func _ground_position(entity: Dictionary, height_above_ground: float = 0.0) -> Vector3:
	var acknex := _acknex_position(entity)
	acknex.z = _ground_z(entity) + height_above_ground
	return AcknexCoordsScript.to_godot_position(acknex)


static func _prop_transform(entity: Dictionary) -> Transform3D:
	return Transform3D(AcknexCoordsScript.prop_basis(_pan(entity)), _godot_position(entity))


static func _character_transform(entity: Dictionary) -> Transform3D:
	return Transform3D(AcknexCoordsScript.character_basis(_pan(entity)), _ground_position(entity))


## InitBonus3/InitKey/InitSmallHeart/InitEyeOfTruth sonar to the ground unless Flag6.
## The pickup prefabs add HeightGem themselves, so the origin sits on the ground.
static func _gem_snapped_transform(entity: Dictionary) -> Transform3D:
	var origin := _ground_position(entity) if not _flag(entity, 6) else _godot_position(entity) - Vector3(0.0, WDL_HEIGHT_GEM * AcknexCoordsScript.SCALE, 0.0)
	return Transform3D(Basis.IDENTITY, origin)


# --- builders -----------------------------------------------------------------


## Editor builds keep instance state so packing a baked level stores only the
## properties that differ from each prefab (not a frozen copy of the prefab).
static func instantiate_edit_state() -> PackedScene.GenEditState:
	return PackedScene.GEN_EDIT_STATE_INSTANCE if OS.has_feature("editor") else PackedScene.GEN_EDIT_STATE_DISABLED


static func _instantiate(scene: PackedScene, entity: Dictionary, placement: Transform3D) -> Node3D:
	var node := scene.instantiate(instantiate_edit_state()) as Node3D
	node.name = node_name_for(entity)
	node.transform = placement
	_store_source_meta(node, entity)
	return node


static func _store_source_meta(node: Node, entity: Dictionary) -> void:
	node.set_meta("wmb_index", int(entity.get("index", -1)))
	node.set_meta("wmb_action", String(entity.get("action_source", entity.get("action", ""))))
	node.set_meta("wmb_file", String(entity.get("file", "")))
	node.set_meta("wmb_skills", PackedFloat32Array(entity.get("skills", [])))
	node.set_meta("wmb_flags", int(entity.get("flags", 0)))


static func _make_marker(entity: Dictionary) -> Node3D:
	var marker := LevelEntityMarkerScript.new() as Marker3D
	marker.name = node_name_for(entity)
	marker.transform = _prop_transform(entity)
	marker.set("source_index", int(entity.get("index", -1)))
	marker.set("action", String(entity.get("action", "")))
	marker.set("source_action", String(entity.get("action_source", "")))
	marker.set("source_name", String(entity.get("name", "")))
	marker.set("source_file", String(entity.get("file", "")))
	marker.set("skills", PackedFloat32Array(entity.get("skills", [])))
	marker.set("flags", int(entity.get("flags", 0)))
	marker.set("acknex_position", _acknex_position(entity))
	marker.set("acknex_angles", AcknexCoordsScript.array_to_vector3(entity.get("angles", [])))
	marker.set("acknex_scale", _acknex_scale(entity))
	return marker


static func _make_diamond(entity: Dictionary) -> Node3D:
	var node := _instantiate(DIAMOND_SCENE, entity, _gem_snapped_transform(entity))
	node.set("points", int(_skill(entity, 2)))
	if _flag(entity, 6):
		node.set("visual_ground_clearance", 0.0)
	if _file(entity) != DEFAULT_DIAMOND_FILE:
		node.set_meta("texture_placeholder_for", _file(entity))
	return node


## gems.wdl InitKey: Skill6 is the key colour (Skill1 is overwritten with the
## bonus identity by InitNewKey).
static func _make_key_diamond(entity: Dictionary) -> Node3D:
	var node := _instantiate(KEY_DIAMOND_SCENE, entity, _gem_snapped_transform(entity))
	var key_path := KeyRules.key_resource_path(int(_skill(entity, 6)))
	if not key_path.is_empty():
		node.set("key_type", load(key_path))
	if _flag(entity, 6):
		node.set("visual_ground_clearance", 0.0)
	return node


## bullets.wdl InitSkinScaleWaspWed: IdEnnemy (Skill1) 0/1 is wasp type 1.
static func _make_wasp_pickup(entity: Dictionary) -> Node3D:
	var node := _instantiate(WASP_PICKUP_SCENE, entity, _prop_transform(entity))
	var wasp_type := clampi(int(_skill(entity, 1)), 1, MAX_WASP_TYPE)
	node.set("wasp_type", load(WASP_TYPE_PATH_FORMAT % wasp_type))
	return node


## mm1.wdl InitDoor/InitDoorWeak and OuvrePortail.
static func _make_gate(entity: Dictionary, weak: bool) -> Node3D:
	var node := _instantiate(KEY_GATE_SCENE, entity, _prop_transform(entity))
	node.set("source_wmb_name", _file(entity))
	node.set("align_source_model_to_origin", true)
	if weak:
		var resistance_skill := _skill(entity, 1)
		if int(resistance_skill) == 0 or int(resistance_skill) == 3333:
			resistance_skill = _skill(entity, 2)
		node.set("destructible_by_wasps", true)
		node.set("weak_door_resistance", clampi(int(resistance_skill), 0, 16))
		node.set("use_source_wmb_behavior", true)
		return node
	var open_height := _skill(entity, 2)
	if open_height <= WDL_DOOR_OPEN_HEIGHT_THRESHOLD:
		open_height = WDL_DOOR_MIN_OPEN_HEIGHT
	node.set("use_wdl_door_fields", true)
	node.set("open_height", open_height * AcknexCoordsScript.SCALE)
	node.set("wdl_skill6_required_key", int(_skill(entity, 6)))
	node.set("wdl_skill5_close_speed", _skill(entity, 5))
	node.set("wdl_skill8_hold_units", _skill(entity, 8))
	node.set("wdl_flag5_permanent", _flag(entity, 5))
	node.set("wdl_flag6_unlocked", _flag(entity, 6))
	node.set("wdl_flag7_exact_match", _flag(entity, 7))
	return node


## mm1.wdl Teleport_Hit: the player moves to (Skill1, Skill2, Skill3) facing Skill4.
static func _make_teleporter(entity: Dictionary) -> Dictionary:
	var node := _instantiate(TELEPORTER_SCENE, entity, _prop_transform(entity))
	# The WMB pad is 32 quants tall around the entity origin (levels sink it 16
	# quants): keep its full height so the top stands above the floor.
	node.set("model_asset_id", String(TELEPORT_MODEL_IDS_BY_FILE.get(_file(entity), "model.teleport.pad")))
	node.set("visual_scale", Vector3.ONE)
	node.set("solid_height", WMB_PAD_HEIGHT * AcknexCoordsScript.SCALE)
	var destination := Marker3D.new()
	destination.name = node_name_for(entity) + "_destination"
	var acknex_destination := Vector3(_skill(entity, 1), _skill(entity, 2), _skill(entity, 3))
	destination.transform = Transform3D(
		AcknexCoordsScript.character_basis(_skill(entity, 4)),
		AcknexCoordsScript.to_godot_position(acknex_destination)
	)
	return {"kind": &"Teleporters", "node": node, "destination": destination}


static func _make_spawner(scene: PackedScene, entity: Dictionary) -> Node3D:
	var node := _instantiate(scene, entity, _prop_transform(entity))
	node.set("source_wmb_name", _file(entity))
	node.set("default_ground_y", _ground_position(entity).y)
	return node


## lion.wdl InitLion: Skill3 LionAttackRange (engage radius, default 500 quants),
## run speed = SpeedEnnemy (Skill2) * LionAccelAttack (Frc(Skill5) * 10).
static func _make_enemy(entity: Dictionary) -> Node3D:
	var file := _file(entity)
	var scene: PackedScene = ENEMY_SCENES_BY_FILE.get(file, RASTA_SCENE)
	var node := _instantiate(scene, entity, _character_transform(entity))
	if not ENEMY_SCENES_BY_FILE.has(file):
		node.set_meta("placeholder_for", file)
	var attack_range := _skill(entity, 3)
	if attack_range <= 0.0:
		attack_range = WDL_DEFAULT_LION_ATTACK_RANGE
	node.set("react_range", attack_range * AcknexCoordsScript.SCALE)
	_apply_lion_family(node, entity)
	var speed_ennemy := floorf(_skill(entity, 2))
	var accel_attack := (_skill(entity, 5) - floorf(_skill(entity, 5))) * 10.0
	var run_speed := speed_ennemy * accel_attack * WDL_SPEED_UNIT_TO_METERS_PER_SECOND
	if run_speed > 0.0:
		node.set("run_speed", run_speed)
	return node


## lion.wdl InitLion: Skill1 = IdEnnemy (family) with EnnemyResistance in its
## fraction (x100), Skill2 = SpeedEnnemy with BounceForce in its fraction (x100).
static func _apply_lion_family(node: Node3D, entity: Dictionary) -> void:
	var id_ennemy_skill := _skill(entity, 1)
	var family: Array = WDL_LION_FAMILIES.get(int(floorf(id_ennemy_skill)), [])
	if family.is_empty():
		return
	var resistance := floorf((id_ennemy_skill - floorf(id_ennemy_skill)) * 100.0 + 0.5)
	if resistance <= 0.0:
		resistance = float(family[2])
	node.set("enemy_family_id", float(family[0]))
	node.set("enemy_weight_force", float(family[1]))
	node.set("enemy_resistance", resistance)
	node.set("max_health", resistance)
	var speed_skill := _skill(entity, 2)
	var bounce_force := floorf((speed_skill - floorf(speed_skill)) * 100.0 + 0.5)
	node.set("push_bounce_force", bounce_force if bounce_force > 0.0 else WDL_LION_FORCE)


## mm1.wdl InitArbre / OnGround: sprite centred half its height above the traced
## ground (InitArbre -4 quants, OnGround -2); Flag1 makes it face the camera.
## Action-less sprites (empty `action`) stay at their placed position.
static func _make_sprite(entity: Dictionary, action: String) -> Node3D:
	var texture_path := "%s/%s.png" % [SPRITE_TEXTURE_ROOT, _clean_name(_file(entity).get_basename())]
	if not _file(entity).ends_with(".pcx") or not ResourceLoader.exists(texture_path):
		return null
	var texture := load(texture_path) as Texture2D
	var sprite := LEVEL_SPRITE_SCENE.instantiate(instantiate_edit_state()) as Sprite3D
	sprite.name = node_name_for(entity)
	sprite.texture = texture
	var acknex_scale := _acknex_scale(entity)
	sprite.pixel_size = AcknexCoordsScript.SCALE * acknex_scale.x
	var height := float(texture.get_height()) * acknex_scale.z
	var center_height := height * 0.5 - (4.0 if action == "initarbre" else 2.0)
	if action == "initarbre":
		if _flag(entity, 1) or _flag(entity, 2):
			center_height = height * 0.5
		elif not is_zero_approx(_skill(entity, 6)):
			center_height = _skill(entity, 6) * acknex_scale.z
	sprite.set("camera_facing", action == "initarbre" and _flag(entity, 1))
	# Sprites without an action keep their placed (centre) position.
	var origin := _godot_position(entity) if action.is_empty() else _ground_position(entity, center_height)
	sprite.transform = Transform3D(AcknexCoordsScript.prop_basis(_pan(entity)), origin)
	_store_source_meta(sprite, entity)
	return sprite


static func _decor_transform(entity: Dictionary) -> Transform3D:
	var acknex := _acknex_position(entity)
	acknex.z = _skill(entity, 3) if not is_zero_approx(_skill(entity, 3)) else WDL_DECOR_DEFAULT_Z
	var acknex_scale := _acknex_scale(entity)
	if is_equal_approx(acknex_scale.x, 1.0):
		acknex_scale.x = WDL_DECOR_DEFAULT_SCALE_XY
		acknex_scale.y = WDL_DECOR_DEFAULT_SCALE_XY
	acknex_scale.z = _skill(entity, 4) if not is_zero_approx(_skill(entity, 4)) else WDL_DECOR_DEFAULT_SCALE_Z
	return _scaled_transform(entity, acknex, acknex_scale)


static func _sky_transform(entity: Dictionary) -> Transform3D:
	var acknex := _acknex_position(entity)
	var acknex_scale := _acknex_scale(entity)
	if is_equal_approx(acknex_scale.x, 1.0):
		acknex_scale.x = WDL_SKY_DEFAULT_SCALE_XY
		acknex_scale.y = WDL_SKY_DEFAULT_SCALE_XY
	acknex_scale.z = _skill(entity, 4) if not is_zero_approx(_skill(entity, 4)) else WDL_SKY_DEFAULT_SCALE_Z
	if not _flag(entity, 1):
		acknex.z = WDL_SKY_BASE_Z + _skill(entity, 3) * 10.0
	return _scaled_transform(entity, acknex, acknex_scale)


static func _scaled_transform(entity: Dictionary, acknex_position: Vector3, acknex_scale: Vector3) -> Transform3D:
	var basis := AcknexCoordsScript.prop_basis(_pan(entity)).scaled_local(Vector3(acknex_scale.x, acknex_scale.z, acknex_scale.y))
	return Transform3D(basis, AcknexCoordsScript.to_godot_position(acknex_position))


static func _make_model_prop(entity: Dictionary, placement: Transform3D) -> Node3D:
	var asset_id := String(MODEL_ASSET_IDS_BY_FILE.get(_file(entity), ""))
	if asset_id.is_empty() or not AssetsScript.CATALOG.has(asset_id):
		return null
	var model_path := String(AssetsScript.CATALOG[asset_id]["path"])
	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		return null
	var prop := Node3D.new()
	prop.set_script(ModelPropScript)
	prop.name = node_name_for(entity)
	prop.set("asset_id", asset_id)
	prop.transform = placement
	var visual := model_scene.instantiate(instantiate_edit_state()) as Node3D
	visual.name = "Visual"
	visual.scale = Vector3.ONE * AcknexCoordsScript.SCALE
	prop.add_child(visual)
	_store_source_meta(prop, entity)
	return prop


## mm1.wdl InitMDL: Skill2-4 override scale_x/y/z, Skill5 sonars to ground + Skill5.
static func _make_init_mdl_prop(entity: Dictionary) -> Node3D:
	var acknex_scale := _acknex_scale(entity)
	if not is_zero_approx(_skill(entity, 2)):
		acknex_scale.x = _skill(entity, 2)
	if not is_zero_approx(_skill(entity, 3)):
		acknex_scale.y = _skill(entity, 3)
	if not is_zero_approx(_skill(entity, 4)):
		acknex_scale.z = _skill(entity, 4)
	var origin := _ground_position(entity, _skill(entity, 5)) if not is_zero_approx(_skill(entity, 5)) else _godot_position(entity)
	var model_path := _catalog_model_path(_file(entity))
	var collision_mode: int = LevelStaticPropScript.CollisionMode.NONE if DECOR_MODEL_FILES.has(_file(entity)) else LevelStaticPropScript.CollisionMode.BOX
	var prop := _make_static_prop(entity, model_path, AcknexCoordsScript.SCALE, acknex_scale, origin, collision_mode)
	if prop != null and _flag(entity, 1):
		# Flag1 = WDL overlay (black texels transparent); Skill1 picks the 1-based skin.
		var skin_index := maxi(int(_skill(entity, 1)) - 1, 0)
		var overlay_path := "%s/skins/%s_skin%d_overlay.png" % [model_path.get_base_dir(), model_path.get_file().get_basename(), skin_index]
		if ResourceLoader.exists(overlay_path):
			prop.set("overlay_texture", load(overlay_path))
	return prop


## Entities without an action are plain solid level objects (brush WMBs collide
## with their polygons, models with their bounding box).
static func _make_actionless_static(entity: Dictionary) -> Node3D:
	var file := _file(entity)
	if file.ends_with(".wmb"):
		return _make_static_prop(entity, _brush_model_path(file), 1.0, _acknex_scale(entity), _godot_position(entity), LevelStaticPropScript.CollisionMode.TRIMESH)
	if file.ends_with(".mdl"):
		var collision_mode: int = LevelStaticPropScript.CollisionMode.NONE if DECOR_MODEL_FILES.has(file) else LevelStaticPropScript.CollisionMode.BOX
		return _make_static_prop(entity, _catalog_model_path(file), AcknexCoordsScript.SCALE, _acknex_scale(entity), _godot_position(entity), collision_mode)
	return null


static func _catalog_model_path(file: String) -> String:
	var asset_id := String(MODEL_ASSET_IDS_BY_FILE.get(file, ""))
	if asset_id.is_empty() or not AssetsScript.CATALOG.has(asset_id):
		return ""
	return String(AssetsScript.CATALOG[asset_id]["path"])


static func _brush_model_path(file: String) -> String:
	var stem := _clean_name(file.get_basename())
	for family_dir: String in BRUSH_MODEL_FAMILY_DIRS:
		var candidate := "%s/%s/%s.gltf" % [family_dir, stem, stem]
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


## `model_unit_scale` converts the model's own units to meters (0.01 for MDL
## glTFs in quants, 1.0 for converted brush WMBs). The entity scale goes on the
## visual so the physics body is never scaled.
static func _make_static_prop(entity: Dictionary, model_path: String, model_unit_scale: float, acknex_scale: Vector3, origin: Vector3, collision_mode: int) -> Node3D:
	if model_path.is_empty():
		return null
	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		return null
	var prop := StaticBody3D.new()
	prop.set_script(LevelStaticPropScript)
	prop.name = node_name_for(entity)
	prop.transform = Transform3D(AcknexCoordsScript.prop_basis(_pan(entity)), origin)
	prop.set("collision_mode", collision_mode)
	var visual := model_scene.instantiate(instantiate_edit_state()) as Node3D
	visual.name = "Visual"
	visual.scale = Vector3(acknex_scale.x, acknex_scale.z, acknex_scale.y) * model_unit_scale
	prop.add_child(visual)
	_store_source_meta(prop, entity)
	return prop


static func _clean_name(value: String) -> String:
	var cleaned := ""
	for index in value.length():
		var character := value.substr(index, 1).to_lower()
		var is_alnum := (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		cleaned += character if is_alnum else "_"
	var parts := PackedStringArray()
	for part in cleaned.split("_", false):
		parts.append(part)
	return "_".join(parts) if not parts.is_empty() else "unnamed"
