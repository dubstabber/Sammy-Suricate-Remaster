extends RefCounted
class_name MenuWmbMetadata

const ACTION_PLAY := 1
const ACTION_TUTORIAL := 2
const ACTION_JUMP := 3
const ACTION_THINK := 4
const ACTION_OPTIONS := 5
const ACTION_QUIT := 6
const ACTION_BACK := 20
const ACTION_BONUS := 50

const SOURCE_LEVEL := "menu_greenpepper.WMB"

const HUB_VIEW_MAIN := &"main"
const HUB_VIEW_TUTORIAL := &"tutorial"
const HUB_VIEW_JUMP := &"jump"
const HUB_VIEW_THINK := &"think"
const HUB_VIEW_BONUS := &"bonus"

const CAMERA_MAIN := {
	"position": Vector3(0.0, 2.2, 6.4),
	"rotation_degrees": Vector3(-7.0, 0.0, 0.0),
	"fov": 70.0,
	"source": "interfac.wdl MainMenu: CameraPosOrigine/CameraAngleOrigine"
}

const CAMERA_BRANCHES := {
	HUB_VIEW_TUTORIAL: {
		"position": Vector3(-3.7, 3.6, 7.2),
		"rotation_degrees": Vector3(-24.0, -13.0, 0.0),
		"source_position": Vector3(60.970, -89.683, -43.429),
		"source_name": "PosTutorialLevels"
	},
	HUB_VIEW_JUMP: {
		"position": Vector3(0.0, 3.85, 7.0),
		"rotation_degrees": Vector3(-25.0, 0.0, 0.0),
		"source_position": Vector3(-59.650, -40.720, -13.462),
		"source_name": "PosJumpLevels"
	},
	HUB_VIEW_THINK: {
		"position": Vector3(3.7, 3.6, 7.2),
		"rotation_degrees": Vector3(-24.0, 13.0, 0.0),
		"source_position": Vector3(2.560, 0.320, -6.680),
		"source_name": "PosThinkLevels"
	},
	HUB_VIEW_BONUS: {
		"position": Vector3(0.0, 2.6, 9.1),
		"rotation_degrees": Vector3(-18.0, 0.0, 0.0),
		"source_position": Vector3(-61.840, -42.251, -12.560),
		"source_name": "PosBonusLevels"
	}
}

const MENU_ITEMS := [
	{
		"node_name": "PlayItem",
		"action_id": ACTION_PLAY,
		"action_key": &"play",
		"source_wmb": "titplay.wmb",
		"asset_id": "model.menu.item.play",
		"position": Vector3(0.0, 0.7, -5.25),
		"scale": Vector3(1.45, 1.45, 1.45),
		"source_position": Vector3(3.280, 2.800, -5.280),
		"collision_size": Vector3(1.6, 1.15, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03
	},
	{
		"node_name": "TutorialItem",
		"action_id": ACTION_TUTORIAL,
		"action_key": HUB_VIEW_TUTORIAL,
		"source_wmb": "tittutor.wmb",
		"asset_id": "model.menu.item.tutorial",
		"position": Vector3(0.0, 5.9, -5.55),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(3.280, 3.440, -5.280),
		"collision_size": Vector3(1.55, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03
	},
	{
		"node_name": "JumpItem",
		"action_id": ACTION_JUMP,
		"action_key": HUB_VIEW_JUMP,
		"source_wmb": "titjump.wmb",
		"asset_id": "model.menu.item.jump",
		"position": Vector3(-5.55, 3.55, -5.45),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(-3.760, 2.800, -6.040),
		"collision_size": Vector3(1.45, 1.05, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03
	},
	{
		"node_name": "ThinkItem",
		"action_id": ACTION_THINK,
		"action_key": HUB_VIEW_THINK,
		"source_wmb": "titpuzzl.wmb",
		"asset_id": "model.menu.item.think",
		"position": Vector3(5.55, 3.55, -5.45),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(0.040, 0.960, -5.600),
		"collision_size": Vector3(1.55, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03
	},
	{
		"node_name": "BonusItem",
		"action_id": ACTION_BONUS,
		"action_key": HUB_VIEW_BONUS,
		"source_wmb": "titbonus.wmb",
		"asset_id": "model.menu.item.bonus",
		"position": Vector3(6.0, 4.65, -5.6),
		"scale": Vector3(1.15, 1.15, 1.15),
		"source_position": Vector3(5.120, -1.360, -6.680),
		"collision_size": Vector3(1.6, 1.15, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03,
		"visible_by_default": false
	},
	{
		"node_name": "OptionsItem",
		"action_id": ACTION_OPTIONS,
		"action_key": &"options",
		"source_wmb": "titoptio.wmb",
		"asset_id": "model.menu.item.options",
		"position": Vector3(-7.1, 0.3, -5.05),
		"scale": Vector3(1.45, 1.45, 1.45),
		"source_position": Vector3(0.000, 4.320, -4.800),
		"collision_size": Vector3(1.65, 1.15, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill7": 10.03
	},
	{
		"node_name": "QuitItem",
		"action_id": ACTION_QUIT,
		"action_key": &"quit",
		"source_wmb": "titquit.wmb",
		"asset_id": "model.menu.item.quit",
		"position": Vector3(7.0, 0.45, -5.05),
		"scale": Vector3(1.22, 1.22, 1.22),
		"source_position": Vector3(34.901, -0.608, -2.998),
		"collision_size": Vector3(1.65, 1.15, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": false,
		"source_skill7": 0.0
	}
]

const MENU_COMPANION_PARTS := [
	{
		"node_name": "PlayBottomPart",
		"action_id": ACTION_PLAY,
		"action_key": &"play",
		"source_wmb": "titplay2.wmb",
		"asset_id": "model.menu.item.play_gem_1",
		"position": Vector3(0.0, 0.7, -5.33),
		"scale": Vector3(1.45, 1.45, 1.45),
		"source_position": Vector3(0.040, 1.440, -5.600),
		"collision_size": Vector3(0.8, 1.35, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill2": 7.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0
	},
	{
		"node_name": "PlayTopPart",
		"action_id": ACTION_PLAY,
		"action_key": &"play",
		"source_wmb": "titplay3.wmb",
		"asset_id": "model.menu.item.play_gem_2",
		"position": Vector3(0.0, 0.7, -5.34),
		"scale": Vector3(1.45, 1.45, 1.45),
		"source_position": Vector3(-3.840, 3.440, -6.040),
		"collision_size": Vector3(1.85, 0.75, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill4": 7.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0
	},
	{
		"node_name": "TutorialBottomPart",
		"action_id": ACTION_TUTORIAL,
		"action_key": HUB_VIEW_TUTORIAL,
		"source_wmb": "tittuto2.wmb",
		"asset_id": "model.menu.item.tutorial_gem",
		"position": Vector3(0.0, 5.9, -5.62),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(-2.164, 0.269, -5.346),
		"rotation_degrees": Vector3(0.0, 108.0, 0.0),
		"collision_size": Vector3(0.8, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill2": -4.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0
	},
	{
		"node_name": "JumpBottomPart",
		"action_id": ACTION_JUMP,
		"action_key": HUB_VIEW_JUMP,
		"source_wmb": "titjum2.wmb",
		"asset_id": "model.menu.item.jump_gem",
		"position": Vector3(-5.55, 3.55, -5.52),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(21.354, 0.269, 10.738),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"collision_size": Vector3(0.8, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill2": 4.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0
	},
	{
		"node_name": "ThinkBottomPart",
		"action_id": ACTION_THINK,
		"action_key": HUB_VIEW_THINK,
		"source_wmb": "titpuzz2.wmb",
		"asset_id": "model.menu.item.think_gem",
		"position": Vector3(5.55, 3.55, -5.52),
		"scale": Vector3(1.55, 1.55, 1.55),
		"source_position": Vector3(0.040, 0.320, -5.600),
		"collision_size": Vector3(0.8, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill2": 4.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0
	},
	{
		"node_name": "BonusBottomPart",
		"action_id": ACTION_BONUS,
		"action_key": HUB_VIEW_BONUS,
		"source_wmb": "titbonu2.wmb",
		"asset_id": "model.menu.item.bonus_gem",
		"position": Vector3(6.0, 4.65, -5.68),
		"scale": Vector3(1.15, 1.15, 1.15),
		"source_position": Vector3(2.560, 0.960, -6.680),
		"collision_size": Vector3(0.8, 1.1, 0.45),
		"hover_lift": 0.0,
		"hover_scale": 1.0,
		"animated": true,
		"source_skill2": 4.0,
		"source_skill7": 10.03,
		"animation_phase_offset": 0.0,
		"visible_by_default": false
	}
]


static func camera_for_view(view_key: StringName) -> Dictionary:
	if view_key == HUB_VIEW_MAIN:
		return CAMERA_MAIN
	return CAMERA_BRANCHES.get(view_key, CAMERA_MAIN)


static func source_name_for_action(action_id: int) -> String:
	for item: Dictionary in MENU_ITEMS:
		if int(item["action_id"]) == action_id:
			return "%s:%s" % [SOURCE_LEVEL, String(item["source_wmb"])]
	return SOURCE_LEVEL
