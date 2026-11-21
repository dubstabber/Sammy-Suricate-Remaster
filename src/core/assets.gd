extends Node

const AssetEntryScript := preload("res://src/resources/asset_entry.gd")

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_CHARACTER_FORWARD_ROTATION := Vector3(0.0, 90.0, 0.0)
# WDL InitMarche uses HeightFootPlayer to place Sammy's entity origin above ground.
const SAMMY_ORIGIN_GROUND_HEIGHT := 4.4

const CATALOG := {
    "model.sammy.static": {
        "path": "res://assets/models/suricat1/suricat1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1.gltf",
        "kind": "model",
        "description": "Sammy first-frame model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0),
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "origin_ground_height": SAMMY_ORIGIN_GROUND_HEIGHT
    },
    "model.sammy.animated": {
        "path": "res://assets/models/suricat1/suricat1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1_animated.gltf",
        "kind": "model",
        "description": "Sammy morph-target animation preview model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0),
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "origin_ground_height": SAMMY_ORIGIN_GROUND_HEIGHT,
        "animation_library": "res://assets/animations/suricat1_clips.tres",
        "default_animation": "stand"
    },
    "model.rasta.animated": {
        "path": "res://assets/models/rasta/rasta_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/rasta/rasta_animated.gltf",
        "kind": "model",
        "description": "Rasta enemy morph-target animation preview model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/rasta_clips.tres",
        "default_animation": "stand"
    },
    "model.punk.animated": {
        "path": "res://assets/models/Punk/Punk_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/Punk/Punk_animated.gltf",
        "kind": "model",
        "description": "Punk enemy morph-target animation preview model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/punk_clips.tres",
        "default_animation": "stand"
    },
    "model.scorpion.animated": {
        "path": "res://assets/models/scorpion/scorpion_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/scorpion/scorpion_animated.gltf",
        "kind": "model",
        "description": "Scorpion enemy morph-target animation preview model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/scorpion_clips.tres",
        "default_animation": "stand"
    },
    "model.sky3": {
        "path": "res://assets/models/sky3/sky3.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky3/sky3.gltf",
        "kind": "model",
        "description": "Original sky reference model"
    },
    "model.menu.floor": {
        "path": "res://assets/models/menu/solmenu5/solmenu5.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/solmenu5/solmenu5.gltf",
        "kind": "model",
        "description": "Original solmenu5 model used by menu_greenpepper.WMB"
    },
    "model.sky2": {
        "path": "res://assets/models/sky2/sky2.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky2/sky2.gltf",
        "kind": "model",
        "description": "Original level sky model (InitSkyMenu)"
    },
    "model.sky4": {
        "path": "res://assets/models/sky4/sky4.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky4/sky4.gltf",
        "kind": "model",
        "description": "Original level sky model (InitSkyMenu)"
    },
    "model.sky5": {
        "path": "res://assets/models/sky5/sky5.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky5/sky5.gltf",
        "kind": "model",
        "description": "Original level sky model (InitSkyMenu)"
    },
    "model.solmenu4": {
        "path": "res://assets/models/solmenu4/solmenu4.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/solmenu4/solmenu4.gltf",
        "kind": "model",
        "description": "Original level floor/sky decor model (InitDecor/InitSkyMenu)"
    },
    "model.bigtree1": {
        "path": "res://assets/models/bigtree1/bigtree1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/bigtree1/bigtree1.gltf",
        "kind": "model",
        "description": "Original big tree backdrop model (InitSkyMenu)"
    },
    "model.greenhi1": {
        "path": "res://assets/models/greenhi1/greenhi1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/greenhi1/greenhi1.gltf",
        "kind": "model",
        "description": "Original green hill decor model (InitDecor)"
    },
    "model.grate1": {
        "path": "res://assets/models/grate1/grate1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/grate1/grate1.gltf",
        "kind": "model",
        "description": "Original grate level model (InitMDL)"
    },
    "model.huttop2": {
        "path": "res://assets/models/huttop2/huttop2.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/huttop2/huttop2.gltf",
        "kind": "model",
        "description": "Original hut roof level model (InitMDL)"
    },
    "model.menu.title": {
        "path": "res://assets/models/menu/titre/titre.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/titre/titre.gltf",
        "kind": "model",
        "description": "Original titre model used by menu_greenpepper.WMB"
    },
	"model.win.title": {
		"path": "res://assets/models/win/Win/Win.gltf",
		"source": "extract-sammy-assets/extracted/godot/models/Win/Win.gltf",
		"kind": "model",
		"description": "Original win.mdl end-level title model",
		"acknex_entity_scale": Vector3(0.32, 0.32, 0.32)
	},
	"model.lose.title": {
		"path": "res://assets/models/lose/Lose.gltf",
		"source": "extract-sammy-assets/extracted/godot/models/Lose/Lose.gltf",
		"kind": "model",
		"description": "Original Lose.mdl lost-level title model (mm1.wdl InitTItleLoose)",
		"acknex_entity_scale": Vector3(0.32, 0.32, 0.32)
	},
    "model.menu.item.play": {
        "path": "res://assets/models/menu/items/titplay/titplay.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titplay.wmb",
        "kind": "model",
        "description": "Original Skill1=1 Play 3D menu WMB"
    },
    "model.menu.item.play_gem_1": {
        "path": "res://assets/models/menu/items/titplay2/titplay2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titplay2.wmb",
        "kind": "model",
        "description": "Original Play menu gem WMB"
    },
    "model.menu.item.play_gem_2": {
        "path": "res://assets/models/menu/items/titplay3/titplay3.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titplay3.wmb",
        "kind": "model",
        "description": "Original Play menu gem WMB variant"
    },
    "model.menu.item.tutorial": {
        "path": "res://assets/models/menu/items/tittutor/tittutor.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/tittutor.wmb",
        "kind": "model",
        "description": "Original Skill1=2 Tutorial 3D menu WMB"
    },
    "model.menu.item.tutorial_gem": {
        "path": "res://assets/models/menu/items/tittuto2/tittuto2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/tittuto2.wmb",
        "kind": "model",
        "description": "Original Tutorial menu gem WMB"
    },
    "model.menu.item.jump": {
        "path": "res://assets/models/menu/items/titjump/titjump.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titjump.wmb",
        "kind": "model",
        "description": "Original Skill1=3 Jump 3D menu WMB"
    },
    "model.menu.item.jump_gem": {
        "path": "res://assets/models/menu/items/titjum2/titjum2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titjum2.wmb",
        "kind": "model",
        "description": "Original Jump menu animated companion WMB"
    },
    "model.menu.item.think": {
        "path": "res://assets/models/menu/items/titpuzzl/titpuzzl.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titpuzzl.wmb",
        "kind": "model",
        "description": "Original Skill1=4 Think/Puzzle 3D menu WMB"
    },
    "model.menu.item.think_gem": {
        "path": "res://assets/models/menu/items/titpuzz2/titpuzz2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titpuzz2.wmb",
        "kind": "model",
        "description": "Original Think/Puzzle menu gem WMB"
    },
    "model.menu.item.bonus": {
        "path": "res://assets/models/menu/items/titbonus/titbonus.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titbonus.wmb",
        "kind": "model",
        "description": "Original Skill1=50 Bonus 3D menu WMB"
    },
    "model.menu.item.bonus_gem": {
        "path": "res://assets/models/menu/items/titbonu2/titbonu2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titbonu2.wmb",
        "kind": "model",
        "description": "Original Bonus menu gem WMB"
    },
    "model.menu.item.options": {
        "path": "res://assets/models/menu/items/titoptio/titoptio.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titoptio.wmb",
        "kind": "model",
        "description": "Original Skill1=5 Options 3D menu WMB"
    },
    "model.menu.item.quit": {
        "path": "res://assets/models/menu/items/titquit/titquit.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/titquit.wmb",
        "kind": "model",
        "description": "Original Skill1=6 Quit 3D menu WMB"
    },
    "model.cactus1": {
        "path": "res://assets/models/cactus1/cactus1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/cactus1/cactus1_animated.gltf",
        "kind": "model",
        "description": "Prototype level prop",
        "animation_library": "res://assets/animations/cactus1_clips.tres",
        "default_animation": "stand"
    },
    "model.boost": {
        "path": "res://assets/models/boost/boost_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/boost/boost_animated.gltf",
        "kind": "model",
        "description": "Prototype collectible prop",
        "animation_library": "res://assets/animations/boost_clips.tres",
        "default_animation": "stand"
    },
    "model.life_heart": {
        "path": "res://assets/models/lifeA/lifeA.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/lifeA/lifeA.gltf",
        "kind": "model",
        "description": "Original InitBonusVie extra-life pickup model"
    },
    "model.platform.default": {
        "path": "res://assets/models/platforms/platfor2/platfor2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor2.wmb",
        "kind": "model",
        "description": "Original inactive moving platform WMB"
    },
    "model.platform.active": {
        "path": "res://assets/models/platforms/platfor1/platfor1.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor1.wmb",
        "kind": "model",
        "description": "Original activated moving platform WMB"
    },
    "model.platform.yellow": {
        "path": "res://assets/models/platforms/platfyel/platfyel.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfyel.wmb",
        "kind": "model",
        "description": "Original yellow key moving platform WMB"
    },
    "model.platform.red": {
        "path": "res://assets/models/platforms/platfred/platfred.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfred.wmb",
        "kind": "model",
        "description": "Original red key moving platform WMB"
    },
    "model.platform.orange": {
        "path": "res://assets/models/platforms/platfora/platfora.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfora.wmb",
        "kind": "model",
        "description": "Original orange key moving platform WMB"
    },
    "model.platform.blue": {
        "path": "res://assets/models/platforms/platfblu/platfblu.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfblu.wmb",
        "kind": "model",
        "description": "Original blue key moving platform WMB"
    },
    "model.platform.magenta": {
        "path": "res://assets/models/platforms/platfmag/platfmag.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfmag.wmb",
        "kind": "model",
        "description": "Original magenta key moving platform WMB"
    },
    "model.platform.green": {
        "path": "res://assets/models/platforms/platgree/platgree.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platgree.wmb",
        "kind": "model",
        "description": "Original green key moving platform WMB"
    },
    "model.platform.column_alt": {
        "path": "res://assets/models/platforms/platfor3/platfor3.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor3.wmb",
        "kind": "model",
        "description": "Original alternate inactive moving platform WMB"
    },
    "model.teleport.pad": {
        "path": "res://assets/models/teleports/teleport/teleport.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
        "kind": "model",
        "description": "Original teleport pad WMB"
    },
    "model.teleport.lion": {
        "path": "res://assets/models/teleports/telelion/telelion.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/telelion.wmb",
        "kind": "model",
        "description": "Original telelion teleport pad WMB (tileteleport3 skin)"
    },
    "model.checkpoint.restart": {
        "path": "res://assets/models/checkpoints/restart/restart.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/restart.wmb",
        "kind": "model",
        "description": "Original restart checkpoint WMB"
    },
	"model.death_pad.tile": {
		"path": "res://assets/models/death_pads/tiledeat/tiledeat.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/tiledeat.wmb",
		"kind": "model",
		"description": "Original TileDeath WMB"
	},
	"model.exit_pad.tile": {
		"path": "res://assets/models/exit_pads/tileexit/tileexit.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/tileexit.wmb",
		"kind": "model",
		"description": "Original TileExit WMB"
	},
	"model.gem_spawner.boulder3": {
		"path": "res://assets/models/spawners/boulder3/boulder3.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/boulder3.wmb",
		"kind": "model",
		"description": "Original boulder3 WMB used by InitBoulder gem spawners"
	},
	"model.gem_spawner.boulder4": {
		"path": "res://assets/models/spawners/boulder4/boulder4.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/boulder4.wmb",
		"kind": "model",
		"description": "Original boulder4 WMB used by InitBoulder gem spawners"
	},
	"model.gem_spawner.boulder5": {
		"path": "res://assets/models/spawners/boulder5/boulder5.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/boulder5.wmb",
		"kind": "model",
		"description": "Original boulder5 WMB used by InitBoulder gem spawners"
	},
	"model.wasp_spawner.hiveblue": {
		"path": "res://assets/models/spawners/hiveblue/hiveblue.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/hiveblue.wmb",
		"kind": "model",
		"description": "Original hiveblue WMB used by InitHive wasp spawners"
	},
	"model.wasp_spawner.hivegree": {
		"path": "res://assets/models/spawners/hivegree/hivegree.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/hivegree.wmb",
		"kind": "model",
		"description": "Original hivegree WMB used by InitHive wasp spawners"
	},
	"model.wasp_spawner.hivemult": {
		"path": "res://assets/models/spawners/hivemult/hivemult.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/hivemult.wmb",
		"kind": "model",
		"description": "Original hivemult WMB used by InitHive wasp spawners"
	},
	"model.wasp_spawner.hivestri": {
		"path": "res://assets/models/spawners/hivestri/hivestri.gltf",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/hivestri.wmb",
		"kind": "model",
		"description": "Original hivestri WMB used by InitHive wasp spawners"
	},
	"texture.gem_spawner.small": {
		"path": "res://assets/textures/spawners/small.png",
		"source": "extract-sammy-assets/extracted/godot/textures/small.png",
		"kind": "texture",
		"description": "Original small.pcx sprite used by small InitBoulder gem spawners"
	},
	"texture.teleport.tile": {
		"path": "res://assets/textures/teleports/tileteleport2.png",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
		"kind": "texture",
        "description": "Original teleport pad top texture decoded from teleport.wmb"
    },
    "texture.teleport.tile_side": {
        "path": "res://assets/textures/teleports/tileteleport2_b.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
        "kind": "texture",
        "description": "Original teleport pad side texture decoded from teleport.wmb"
    },
    "texture.death_pad.tile": {
        "path": "res://assets/textures/death_pads/tiledeath.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/tiledeat.wmb",
        "kind": "texture",
        "description": "Original death pad top texture decoded from tiledeat.wmb"
    },
    "texture.death_pad.tile_border": {
        "path": "res://assets/textures/death_pads/tiledeath_bord.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/tiledeat.wmb",
        "kind": "texture",
        "description": "Original death pad border texture decoded from tiledeat.wmb"
    },
	"texture.exit_pad.tile_nextlevel": {
		"path": "res://assets/textures/exit_pads/tile_nextlevel.png",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/tileexit.wmb",
		"kind": "texture",
		"description": "Original exit pad next-level texture decoded from tileexit.wmb"
	},
	"texture.win.title": {
		"path": "res://assets/models/win/Win/skins/Win_skin0.png",
		"source": "extract-sammy-assets/extracted/godot/models/Win/skins/Win_skin0.png",
		"kind": "texture",
		"description": "Original win.mdl texture"
	},
    "texture.checkpoint.green_grad": {
        "path": "res://assets/textures/checkpoints/green_grad1.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/restart.wmb",
        "kind": "texture",
        "description": "Original restart checkpoint WMB texture"
    },
    "model.enemy_visibility_range": {
        "path": "res://assets/models/circl100/circl100_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/circl100_animated.gltf",
        "kind": "model",
        "description": "Original Eye of Truth enemy range circle model"
    },
    "model.eye_of_truth": {
        "path": "res://assets/models/Paneye/Paneye.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/Paneye/Paneye.gltf",
        "kind": "model",
        "description": "Original Eye of Truth pickup and panel model"
    },
    "texture.enemy_visibility_range.skin_1": {
        "path": "res://assets/models/circl100/skins/circl100_skin0.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin0.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle idle skin"
    },
    "texture.enemy_visibility_range.skin_2": {
        "path": "res://assets/models/circl100/skins/circl100_skin1.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin1.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle alert skin"
    },
    "texture.enemy_visibility_range.skin_3": {
        "path": "res://assets/models/circl100/skins/circl100_skin2.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin2.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle chase skin"
    },
    "texture.eye_truth.panel": {
        "path": "res://assets/models/Paneye/skins/Paneye_skin0.png",
        "source": "extract-sammy-assets/extracted/godot/textures/eyetruth.png",
        "kind": "texture",
        "description": "Original Eye of Truth pickup and panel texture"
    },
	"texture.particle.small_star_1a": {
		"path": "res://assets/textures/particles/tistar1a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar1a.png",
		"kind": "texture",
		"description": "Original SmallStar1A sprite used by particle_Boost1"
	},
	"texture.particle.gem_star_1a": {
		"path": "res://assets/textures/particles/tistar1a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar1a.png",
		"kind": "texture",
		"description": "Original red key-gem trail star A"
	},
	"texture.particle.gem_star_1b": {
		"path": "res://assets/textures/particles/tistar1b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar1b.png",
		"kind": "texture",
		"description": "Original red key-gem trail star B"
	},
	"texture.particle.gem_star_2a": {
		"path": "res://assets/textures/particles/tistar2a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar2a.png",
		"kind": "texture",
		"description": "Original yellow key-gem trail star A"
	},
	"texture.particle.gem_star_2b": {
		"path": "res://assets/textures/particles/tistar2b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar2b.png",
		"kind": "texture",
		"description": "Original yellow key-gem trail star B"
	},
	"texture.particle.gem_star_3a": {
		"path": "res://assets/textures/particles/tistar3a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar3a.png",
		"kind": "texture",
		"description": "Original orange key-gem trail star A"
	},
	"texture.particle.gem_star_3b": {
		"path": "res://assets/textures/particles/tistar3b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar3b.png",
		"kind": "texture",
		"description": "Original orange key-gem trail star B"
	},
	"texture.particle.gem_star_4a": {
		"path": "res://assets/textures/particles/tistar4a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar4a.png",
		"kind": "texture",
		"description": "Original blue key-gem trail star A"
	},
	"texture.particle.gem_star_4b": {
		"path": "res://assets/textures/particles/tistar4b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar4b.png",
		"kind": "texture",
		"description": "Original blue key-gem trail star B"
	},
	"texture.particle.gem_star_5a": {
		"path": "res://assets/textures/particles/tistar5a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar5a.png",
		"kind": "texture",
		"description": "Original magenta key-gem trail star A"
	},
	"texture.particle.gem_star_5b": {
		"path": "res://assets/textures/particles/tistar5b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar5b.png",
		"kind": "texture",
		"description": "Original magenta key-gem trail star B"
	},
	"texture.particle.gem_star_6a": {
		"path": "res://assets/textures/particles/tistar6a.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar6a.png",
		"kind": "texture",
		"description": "Original green key-gem trail star A"
	},
	"texture.particle.gem_star_6b": {
		"path": "res://assets/textures/particles/tistar6b.png",
		"source": "extract-sammy-assets/extracted/godot/textures/tistar6b.png",
		"kind": "texture",
		"description": "Original green key-gem trail star B"
	},
	"texture.particle.gem_fragment_1": {
		"path": "res://assets/textures/particles/morgem1.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem1.png",
		"kind": "texture",
		"description": "Original red key-gem explosion fragment"
	},
	"texture.particle.gem_fragment_2": {
		"path": "res://assets/textures/particles/morgem2.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem2.png",
		"kind": "texture",
		"description": "Original yellow key-gem explosion fragment"
	},
	"texture.particle.gem_fragment_3": {
		"path": "res://assets/textures/particles/morgem3.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem3.png",
		"kind": "texture",
		"description": "Original orange key-gem explosion fragment"
	},
	"texture.particle.gem_fragment_4": {
		"path": "res://assets/textures/particles/morgem4.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem4.png",
		"kind": "texture",
		"description": "Original blue key-gem explosion fragment"
	},
	"texture.particle.gem_fragment_5": {
		"path": "res://assets/textures/particles/morgem5.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem5.png",
		"kind": "texture",
		"description": "Original magenta key-gem explosion fragment"
	},
	"texture.particle.gem_fragment_6": {
		"path": "res://assets/textures/particles/morgem6.png",
		"source": "extract-sammy-assets/extracted/godot/textures/morgem6.png",
		"kind": "texture",
		"description": "Original green key-gem explosion fragment"
	},
    "texture.particle.teleport_star_1": {
        "path": "res://assets/textures/particles/StarHit1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit1.png",
        "kind": "texture",
        "description": "Original StarHit1 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_2": {
        "path": "res://assets/textures/particles/StarHit2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit2.png",
        "kind": "texture",
        "description": "Original StarHit2 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_3": {
        "path": "res://assets/textures/particles/StarHit3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit3.png",
        "kind": "texture",
        "description": "Original StarHit3 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_4": {
        "path": "res://assets/textures/particles/StarHit4.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit4.png",
        "kind": "texture",
        "description": "Original StarHit4 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_5": {
        "path": "res://assets/textures/particles/StarHit5.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit5.png",
        "kind": "texture",
        "description": "Original StarHit5 sprite used by particle_Teleport"
    },
    "texture.particle.checkpoint_green_1": {
        "path": "res://assets/textures/particles/greenpr1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/greenpr1.png",
        "kind": "texture",
        "description": "Original greenparticle1 sprite used by particle_GemRestart"
    },
    "texture.particle.checkpoint_green_2": {
        "path": "res://assets/textures/particles/greenpr2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/greenpr2.png",
        "kind": "texture",
        "description": "Original greenparticle2 sprite used by particle_GemRestart"
    },
    "texture.particle.tile_death_fumee_b1": {
        "path": "res://assets/textures/particles/fumeeB1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumeeB1.png",
        "kind": "texture",
        "description": "Original fumeeB1 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee_b3": {
        "path": "res://assets/textures/particles/fumeeB3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumeeB3.png",
        "kind": "texture",
        "description": "Original fumeeB3 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee_b5": {
        "path": "res://assets/textures/particles/fumeeB5.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumeeB5.png",
        "kind": "texture",
        "description": "Original fumeeB5 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee3": {
        "path": "res://assets/textures/particles/fumee3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee3.png",
        "kind": "texture",
        "description": "Original fumee3 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee5": {
        "path": "res://assets/textures/particles/fumee5.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee5.png",
        "kind": "texture",
        "description": "Original fumee5 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee6": {
        "path": "res://assets/textures/particles/fumee6.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee6.png",
        "kind": "texture",
        "description": "Original fumee6 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee7": {
        "path": "res://assets/textures/particles/fumee7.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee7.png",
        "kind": "texture",
        "description": "Original fumee7 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee8": {
        "path": "res://assets/textures/particles/fumee8.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee8.png",
        "kind": "texture",
        "description": "Original fumee8 sprite used by particle_TileDeath"
    },
    "texture.particle.tile_death_fumee9": {
        "path": "res://assets/textures/particles/fumee9.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fumee9.png",
        "kind": "texture",
        "description": "Original fumee9 sprite used by particle_TileDeath"
    },
    "texture.particle.eye_truth_1": {
        "path": "res://assets/textures/particles/peye1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/peye1.png",
        "kind": "texture",
        "description": "Original particle_RangeLion1 / particle_TakeEyeTruth sprite"
    },
    "texture.particle.eye_truth_2": {
        "path": "res://assets/textures/particles/peye2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/peye2.png",
        "kind": "texture",
        "description": "Original particle_RangeLion2 / particle_TakeEyeTruth sprite"
    },
    "texture.particle.heart_1": {
        "path": "res://assets/textures/particles/heart/phearth1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth1.png",
        "kind": "texture",
        "description": "Original PartHearth1 sprite used by particle_SmallHeart"
    },
    "texture.particle.heart_2": {
        "path": "res://assets/textures/particles/heart/phearth2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth2.png",
        "kind": "texture",
        "description": "Original PartHearth2 sprite"
    },
    "texture.particle.heart_3": {
        "path": "res://assets/textures/particles/heart/phearth3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth3.png",
        "kind": "texture",
        "description": "Original PartHearth3 sprite"
    },
    "texture.particle.heart_4": {
        "path": "res://assets/textures/particles/heart/phearth4.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth4.png",
        "kind": "texture",
        "description": "Original PartHearth4 sprite"
    },
    "texture.particle.heart_5": {
        "path": "res://assets/textures/particles/heart/phearth5.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth5.png",
        "kind": "texture",
        "description": "Original PartHearth5 sprite"
    },
    "texture.particle.heart_6": {
        "path": "res://assets/textures/particles/heart/phearth6.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth6.png",
        "kind": "texture",
        "description": "Original PartHearth6 sprite"
    },
    "texture.particle.heart_7": {
        "path": "res://assets/textures/particles/heart/phearth7.png",
        "source": "extract-sammy-assets/extracted/godot/textures/phearth7.png",
        "kind": "texture",
        "description": "Original PartHearth7 sprite"
    },
    "texture.small_heart": {
        "path": "res://assets/textures/heart/heart+11.png",
        "source": "extract-sammy-assets/extracted/godot/textures/heart+11.png",
        "kind": "texture",
        "description": "Original InitSmallHeart 11-frame red heart sprite sheet"
    },
    "texture.diamond.default": {
        "path": "res://assets/textures/score/gemgr+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemgr+17.png",
        "kind": "texture",
        "description": "Original green score diamond sprite sheet used by InitBonus3"
    },
    "texture.score.plus50": {
        "path": "res://assets/textures/score/plus50+6.png",
        "source": "extract-sammy-assets/extracted/godot/textures/plus50+6.png",
        "kind": "texture",
        "description": "Original +50 flying score sprite sheet"
    },
    "texture.score.plus100": {
        "path": "res://assets/textures/score/plu100+2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/plu100+2.png",
        "kind": "texture",
        "description": "Original +100 flying score sprite sheet"
    },
    "texture.key_diamond.red": {
        "path": "res://assets/textures/key_diamonds/gemre+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemre+17.png",
        "kind": "texture",
        "description": "Original red key-diamond sprite sheet"
    },
    "texture.key_diamond.yellow": {
        "path": "res://assets/textures/key_diamonds/gemye+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemye+17.png",
        "kind": "texture",
        "description": "Original yellow key-diamond sprite sheet"
    },
    "texture.key_diamond.orange": {
        "path": "res://assets/textures/key_diamonds/gemor+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemor+17.png",
        "kind": "texture",
        "description": "Original orange mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.blue": {
        "path": "res://assets/textures/key_diamonds/gembl+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gembl+17.png",
        "kind": "texture",
        "description": "Original blue key-diamond sprite sheet"
    },
    "texture.key_diamond.magenta": {
        "path": "res://assets/textures/key_diamonds/gemma+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemma+17.png",
        "kind": "texture",
        "description": "Original magenta mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.green": {
        "path": "res://assets/textures/key_diamonds/gemve+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemve+17.png",
        "kind": "texture",
        "description": "Original green mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.multi": {
        "path": "res://assets/textures/key_diamonds/gemmu+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemmu+17.png",
        "kind": "texture",
        "description": "Original all-key/multi key-diamond sprite sheet"
    },
    "texture.ui.gem_panel_bar": {
        "path": "res://assets/textures/ui/hbargems.png",
        "source": "extract-sammy-assets/extracted/godot/textures/hbargems.png",
        "kind": "texture",
        "description": "Original key-diamond panel strip"
    },
    "texture.ui.gem_panel_background": {
        "path": "res://assets/textures/ui/fondgems.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fondgems.png",
        "kind": "texture",
        "description": "Original key-diamond panel background"
    },
    "texture.menu.play": {
        "path": "res://assets/textures/menu/startpep.png",
        "source": "extract-sammy-assets/extracted/godot/textures/startpep.png",
        "kind": "texture",
        "description": "Original startpep menu texture"
    },
    "texture.menu.options": {
        "path": "res://assets/textures/menu/butpad1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/butpad1.png",
        "kind": "texture",
        "description": "Original menu pad texture used as the first-pass options placeholder"
    },
    "texture.menu.options_hover": {
        "path": "res://assets/textures/menu/butpad2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/butpad2.png",
        "kind": "texture",
        "description": "Original menu pad hover texture used as the first-pass options placeholder"
    },
    "texture.menu.quit": {
        "path": "res://assets/textures/menu/quit1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/quit1.png",
        "kind": "texture",
        "description": "Original quit menu texture"
    },
    "texture.menu.quit_hover": {
        "path": "res://assets/textures/menu/quit2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/quit2.png",
        "kind": "texture",
        "description": "Original quit menu hover texture"
    },
    "texture.menu.options.background": {
        "path": "res://assets/textures/menu/options/fondopt1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fondopt1.png",
        "kind": "texture",
        "description": "Original options panel background"
    },
    "texture.menu.options.audio": {
        "path": "res://assets/textures/menu/options/audio1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/audio1.png",
        "kind": "texture",
        "description": "Original options audio label"
    },
    "texture.menu.options.audio_hover": {
        "path": "res://assets/textures/menu/options/audio2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/audio2.png",
        "kind": "texture",
        "description": "Original options audio hover label"
    },
    "texture.menu.options.resume": {
        "path": "res://assets/textures/menu/options/resum1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/resum1.png",
        "kind": "texture",
        "description": "Original options resume button"
    },
    "texture.menu.options.resume_hover": {
        "path": "res://assets/textures/menu/options/resum2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/resum2.png",
        "kind": "texture",
        "description": "Original options resume hover button"
    },
    "texture.menu.options.restart": {
        "path": "res://assets/textures/menu/options/restart2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/restart2.png",
        "kind": "texture",
        "description": "Original in-game options restart button"
    },
    "texture.menu.options.restart_hover": {
        "path": "res://assets/textures/menu/options/restart3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/restart3.png",
        "kind": "texture",
        "description": "Original in-game options restart hover button"
    },
    "texture.menu.options.back": {
        "path": "res://assets/textures/menu/options/back1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/back1.png",
        "kind": "texture",
        "description": "Original options back button"
    },
    "texture.menu.options.back_hover": {
        "path": "res://assets/textures/menu/options/back2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/back2.png",
        "kind": "texture",
        "description": "Original options back hover button"
    },
    "texture.menu.options.quit": {
        "path": "res://assets/textures/menu/options/oui1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/oui1.png",
        "kind": "texture",
        "description": "Original yes/quit confirmation button"
    },
    "texture.menu.options.quit_hover": {
        "path": "res://assets/textures/menu/options/oui2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/oui2.png",
        "kind": "texture",
        "description": "Original yes/quit confirmation hover button"
    },
    "texture.menu.options.no": {
        "path": "res://assets/textures/menu/options/non1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/non1.png",
        "kind": "texture",
        "description": "Original no/cancel confirmation button"
    },
    "texture.menu.options.no_hover": {
        "path": "res://assets/textures/menu/options/non2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/non2.png",
        "kind": "texture",
        "description": "Original no/cancel confirmation hover button"
    },
    "texture.menu.options.quit_prompt": {
        "path": "res://assets/textures/menu/options/fondyn.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fondyn.png",
        "kind": "texture",
        "description": "Original quit confirmation prompt texture"
    },
    "texture.menu.back_arrow": {
        "path": "res://assets/textures/menu/options/mflechA1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/mflechA1.png",
        "kind": "texture",
        "description": "Original menu back arrow texture"
    },
    "music.sammy01": {
        "path": "res://assets/audio/sammy01.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy01.mid",
        "kind": "music",
        "description": "Original sammy01.mid rendered through a Roland GS-compatible MIDI bank"
    },
    "music.sammy02": {
        "path": "res://assets/audio/sammy02.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy02.mid",
        "kind": "music",
        "description": "Original sammy02.mid level track (sons.wdl musique2) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "music.sammy03": {
        "path": "res://assets/audio/sammy03.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy03.mid",
        "kind": "music",
        "description": "Original sammy03.mid level track (sons.wdl musique3) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "music.sammy04": {
        "path": "res://assets/audio/sammy04.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy04.mid",
        "kind": "music",
        "description": "Original sammy04.mid level track (sons.wdl musique4) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "music.sammy05": {
        "path": "res://assets/audio/sammy05.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy05.mid",
        "kind": "music",
        "description": "Original sammy05.mid level track (sons.wdl musique5) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "music.sammy06": {
        "path": "res://assets/audio/sammy06.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy06.mid",
        "kind": "music",
        "description": "Original sammy06.mid level track (sons.wdl musique6) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "music.sammy07": {
        "path": "res://assets/audio/sammy07.ogg",
        "source": "extract-sammy-assets/extracted/wrs/sounds/sammy07.mid",
        "kind": "music",
        "description": "Original sammy07.mid level track (sons.wdl musique7) rendered with TiMidity and the Windows gm.dls GS bank like sammy01 (tools/render_midi_music.py)"
    },
    "sfx.beep1": {
        "path": "res://assets/audio/beep1.wav",
        "source": "extract-sammy-assets/extracted/wrs/sounds/beep1.wav",
        "kind": "sfx",
        "description": "Original beep1.wav played by the mm1.wdl debug/cheat keys"
    },
    "sfx.collect": {
        "path": "res://assets/audio/gemding2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/gemding2.wav",
        "kind": "audio",
        "description": "Gem pickup sound"
    },
    "sfx.colored_gem": {
        "path": "res://assets/audio/gemding2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/gemding2.wav",
        "kind": "audio",
        "description": "Original ColoredGem_son used by key-diamond pickups"
    },
    "sfx.diamond": {
        "path": "res://assets/audio/diam.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/diam.wav",
        "kind": "audio",
        "description": "Original Diam_son used by score diamond pickups"
    },
    "sfx.gem_blink": {
        "path": "res://assets/audio/Cligno1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Cligno1.wav",
        "kind": "audio",
        "description": "Original Cligno1_son used by temporary blinking gems"
    },
    "sfx.menu_hover": {
        "path": "res://assets/audio/Cligno1.wav",
        "source": "extract-sammy-assets/extracted/wrs/scripts/sons.wdl:Toc2=Cligno1.wav",
        "kind": "audio",
        "description": "Original Toc2 menu hover sound"
    },
    "sfx.menu_select": {
        "path": "res://assets/audio/tocbois8.wav",
        "source": "extract-sammy-assets/extracted/wrs/scripts/sons.wdl:Ding1=tocbois8.wav",
        "kind": "audio",
        "description": "Original Ding1 menu click sound"
    },
    "sfx.menu_option_select": {
        "path": "res://assets/audio/tocbois6.wav",
        "source": "extract-sammy-assets/extracted/wrs/scripts/sons.wdl:Ding2=tocbois6.wav",
        "kind": "audio",
        "description": "Original Ding2 secondary menu click sound"
    },
    "sfx.gem_break": {
        "path": "res://assets/audio/broken4.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/broken4.wav",
        "kind": "audio",
        "description": "Original broken4 sound used when key gems explode"
    },
    "sfx.gem_bounce_high": {
        "path": "res://assets/audio/ding6.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/ding6.wav",
        "kind": "audio",
        "description": "Original first key-gem bounce sound"
    },
    "sfx.gem_bounce_mid": {
        "path": "res://assets/audio/ding5.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/ding5.wav",
        "kind": "audio",
        "description": "Original second key-gem bounce sound"
    },
    "sfx.gem_bounce_low": {
        "path": "res://assets/audio/ding3.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/ding3.wav",
        "kind": "audio",
        "description": "Original third key-gem bounce sound"
    },
    "sfx.gem_bounce_last": {
        "path": "res://assets/audio/ding7.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/ding7.wav",
        "kind": "audio",
        "description": "Original later key-gem bounce sound"
    },
    "sfx.boost_pickup": {
        "path": "res://assets/audio/Chimes2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Chimes2.wav",
        "kind": "audio",
        "description": "Original speed boost pickup chime"
    },
    "sfx.get_life": {
        "path": "res://assets/audio/getlife.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/getlife.wav",
        "kind": "audio",
        "description": "Original GetLife_son used by InitBonusVie"
    },
    "sfx.gagne1": {
        "path": "res://assets/audio/gagne1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/gagne1.wav",
        "kind": "audio",
        "description": "Original Gagne1 used by InitSmallHeart"
    },
    "sfx.score_reach": {
        "path": "res://assets/audio/applause.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/applause.wav",
        "kind": "audio",
        "description": "Original ScoreReach_son played when Sammy reaches ScoreGoal"
    },
	"sfx.win": {
		"path": "res://assets/audio/Iwin.wav",
		"source": "extract-sammy-assets/extracted/godot/audio/Iwin.wav",
		"kind": "audio",
		"description": "Original Win_son played by TileExit_Hit"
	},
    "sfx.eye_truth": {
        "path": "res://assets/audio/EyeTruth.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/EyeTruth.wav",
        "kind": "audio",
        "description": "Original EyeTruth_son pickup sound"
    },
    "sfx.quick_turn": {
        "path": "res://assets/audio/Blouit.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Blouit.wav",
        "kind": "audio",
        "description": "Original Blouit_son used by RetourneSammy quick turn"
    },
    "sfx.checkpoint_restart": {
        "path": "res://assets/audio/Restart.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Restart.wav",
        "kind": "audio",
        "description": "Original Restart_son used when activating a restart checkpoint"
    },
    "sfx.key_mix": {
        "path": "res://assets/audio/Gemmix.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Gemmix.wav",
        "kind": "audio",
        "description": "Original GemMixing_son used when two key diamonds combine"
    },
    "sfx.key_mix_end": {
        "path": "res://assets/audio/EndGemmi.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/EndGemmi.wav",
        "kind": "audio",
        "description": "Original EndGemMixing_son used at the end of key mixing"
    },
    "sfx.door_open": {
        "path": "res://assets/audio/dooropen.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/dooropen.wav",
        "kind": "audio",
        "description": "Original DoorOpen_son"
    },
    "sfx.door_close": {
        "path": "res://assets/audio/doorclos.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/doorclos.wav",
        "kind": "audio",
        "description": "Original DoorClose_son"
    },
    "sfx.plank1": {
        "path": "res://assets/audio/plank1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/plank1.wav",
        "kind": "audio",
        "description": "Original Plank1_son used by weak-door hits and debris"
    },
    "sfx.plank2": {
        "path": "res://assets/audio/plank2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/plank2.wav",
        "kind": "audio",
        "description": "Original Plank2_son used by weak-door debris bounces"
    },
    "model.weak_gate.plank1": {
        "path": "res://assets/models/weak_gate_planks/plank1/plank1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/plank1/plank1.gltf",
        "kind": "model",
        "description": "Original plank1 debris model launched by weak-door destruction"
    },
    "model.weak_gate.plank2": {
        "path": "res://assets/models/weak_gate_planks/plank2/plank2.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/plank2/plank2.gltf",
        "kind": "model",
        "description": "Original plank2 debris model launched by weak-door destruction"
    },
    "model.weak_gate.plank3": {
        "path": "res://assets/models/weak_gate_planks/plank3/plank3.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/plank3/plank3.gltf",
        "kind": "model",
        "description": "Original plank3 debris model launched by weak-door destruction"
    },
    "sfx.platform_activate": {
        "path": "res://assets/audio/platfor2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/platfor2.wav",
        "kind": "audio",
        "description": "Original Platform1_son used when moving platforms activate"
    },
    "sfx.hit": {
        "path": "res://assets/audio/Hit1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Hit1.wav",
        "kind": "audio",
        "description": "Original Hit1 impact sound compatibility alias"
    },
    "sfx.enemy_hit_1": {
        "path": "res://assets/audio/Hit1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Hit1.wav",
        "kind": "audio",
        "description": "Original Hit1_Son player impact cue used by enemy attacks"
    },
    "sfx.enemy_hit_2": {
        "path": "res://assets/audio/Hit2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Hit2.wav",
        "kind": "audio",
        "description": "Original Hit2_Son player impact cue used by enemy attacks"
    },
    "sfx.enemy_hit_3": {
        "path": "res://assets/audio/Hit3.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Hit3.wav",
        "kind": "audio",
        "description": "Original Hit3_Son player impact cue used by enemy attacks"
    },
    "sfx.wasp": {
        "path": "res://assets/audio/wasp.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/wasp.wav",
        "kind": "audio",
        "description": "Wasp sound"
    },
    "sfx.error": {
        "path": "res://assets/audio/error1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/error1.wav",
        "kind": "audio",
        "description": "Original Error1_son used for rejected actions"
    },
    "sfx.takewasp": {
        "path": "res://assets/audio/takewasp.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/takewasp.wav",
        "kind": "audio",
        "description": "Original TakeWasp_son wasp pickup chime"
    },
    "sfx.wasp_kaput": {
        "path": "res://assets/audio/WaspKapu.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/WaspKapu.wav",
        "kind": "audio",
        "description": "Original WaspKaputt_son wasp impact sound"
    },
    "sfx.scorpion_attack": {
        "path": "res://assets/audio/scoratt1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/scoratt1.wav",
        "kind": "audio",
        "description": "Original ScorpionAttack_son used by scorpion attacks"
    },
    "sfx.scorpion_walk": {
        "path": "res://assets/audio/scorwalk.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/scorwalk.wav",
        "kind": "audio",
        "description": "Original ScorpionWalk_son used when scorpions return to walking"
    },
    "model.wasp1": {
        "path": "res://assets/models/wasp1/wasp1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/wasp1/wasp1_animated.gltf",
        "kind": "model",
        "description": "Original wasp projectile morph-target animation model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "animation_library": "res://assets/animations/wasp1_clips.tres",
        "default_animation": "stand"
    },
    "sfx.player": {
        "path": "res://assets/audio/haway.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/haway.wav",
        "kind": "audio",
        "description": "Player vocalization sample"
    },
    "metadata.wmb_manifest": {
        "path": "res://assets/metadata/wmb_manifest.json",
        "source": "extract-sammy-assets/extracted/godot/levels/wmb_manifest.json",
        "kind": "metadata",
        "description": "WMB dependency manifest copied from extraction output"
    },
    "metadata.menu_wmb_manifest": {
        "path": "res://assets/models/menu/items/menu_wmb_manifest.json",
        "source": "extract-sammy-assets/extracted/godot/raw/levels",
        "kind": "metadata",
        "description": "Converted original 3D main-menu item WMB manifest"
    },
    "metadata.platform_wmb_manifest": {
        "path": "res://assets/models/platforms/platform_wmb_manifest.json",
        "source": "extract-sammy-assets/extracted/godot/raw/levels",
        "kind": "metadata",
        "description": "Converted original moving platform WMB manifest"
    },
	"metadata.checkpoint_wmb_manifest": {
		"path": "res://assets/models/checkpoints/checkpoint_wmb_manifest.json",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/restart.wmb",
		"kind": "metadata",
		"description": "Converted original restart checkpoint WMB manifest"
	},
	"metadata.exit_pad_wmb_manifest": {
		"path": "res://assets/models/exit_pads/exit_pad_wmb_manifest.json",
		"source": "extract-sammy-assets/extracted/godot/raw/levels/tileexit.wmb",
		"kind": "metadata",
		"description": "Converted original TileExit WMB manifest"
	},
	"metadata.gem_spawner_wmb_manifest": {
		"path": "res://assets/models/spawners/gem_spawner_wmb_manifest.json",
		"source": "extract-sammy-assets/extracted/godot/raw/levels",
		"kind": "metadata",
		"description": "Converted original InitBoulder gem spawner WMB manifest"
	},
	"metadata.wasp_spawner_wmb_manifest": {
		"path": "res://assets/models/spawners/hive_spawner_wmb_manifest.json",
		"source": "extract-sammy-assets/extracted/godot/raw/levels",
		"kind": "metadata",
		"description": "Converted original InitHive wasp spawner WMB manifest"
	}
}

var entries: Dictionary = {}


func _ready() -> void:
    rebuild()


func rebuild() -> void:
    entries.clear()
    for entry_id: String in CATALOG.keys():
        var raw: Dictionary = CATALOG[entry_id]
        entries[entry_id] = AssetEntryScript.new(
                entry_id,
                raw.get("path", ""),
                raw.get("source", ""),
                raw.get("kind", ""),
                raw.get("description", ""),
                raw.get("acknex_entity_scale", Vector3.ONE),
                raw.get("rotation_degrees", Vector3.ZERO),
                bool(raw.get("ground_to_floor", false)),
                float(raw.get("origin_ground_height", 0.0)),
                raw.get("animation_library", ""),
                raw.get("default_animation", "")
        )


func has_asset(entry_id: String) -> bool:
    _ensure_built()
    return entries.has(entry_id)


func get_entry(entry_id: String) -> Resource:
    _ensure_built()
    return entries.get(entry_id)


func get_asset_path(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.path


func load_asset(entry_id: String) -> Resource:
    var asset_resource_path := get_asset_path(entry_id)
    if asset_resource_path.is_empty():
        push_warning("Unknown asset id: %s" % entry_id)
        return null
    return load(asset_resource_path)


func get_model_scale(entry_id: String) -> Vector3:
    var entry := get_entry(entry_id)
    if entry == null:
        return Vector3.ONE * ACKNEX_TO_GODOT_SCALE
    return entry.acknex_entity_scale * ACKNEX_TO_GODOT_SCALE


func get_model_rotation_degrees(entry_id: String) -> Vector3:
    var entry := get_entry(entry_id)
    if entry == null:
        return Vector3.ZERO
    return entry.rotation_degrees


func should_ground_model(entry_id: String) -> bool:
    var entry := get_entry(entry_id)
    if entry == null:
        return false
    return bool(entry.ground_to_floor)


func get_model_origin_ground_height(entry_id: String) -> float:
    var entry := get_entry(entry_id)
    if entry == null:
        return 0.0
    return float(entry.origin_ground_height)


func should_align_model_origin_to_ground(entry_id: String) -> bool:
    return get_model_origin_ground_height(entry_id) > 0.0


func get_model_animation_library_path(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.animation_library_path


func get_model_default_animation(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.default_animation


func get_wasp_skin_path(skin_index: int) -> String:
    if skin_index <= 0:
        return ""
    return "res://assets/models/wasp1/skins/wasp1_skin%d.png" % (skin_index - 1)


func get_wasp_leg_skin_path(skin_index: int) -> String:
    if skin_index <= 0:
        return ""
    return "res://assets/models/wasp1/skins/legs/wasp1_skin%d_legs.png" % (skin_index - 1)


func load_wasp_skin_texture(skin_index: int) -> Texture2D:
    var texture_path := get_wasp_skin_path(skin_index)
    if texture_path.is_empty():
        return null
    if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path):
        return null
    return load(texture_path) as Texture2D


func load_wasp_leg_skin_texture(skin_index: int) -> Texture2D:
    var texture_path := get_wasp_leg_skin_path(skin_index)
    if texture_path.is_empty():
        return null
    if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path):
        return null
    return load(texture_path) as Texture2D


func load_enemy_visibility_range_skin_texture(skin_number: int) -> Texture2D:
    var clamped_skin := clampi(skin_number, 1, 3)
    return load_asset("texture.enemy_visibility_range.skin_%d" % clamped_skin) as Texture2D


func apply_wasp_skin(model_root: Node3D, skin_index: int) -> bool:
    if model_root == null:
        return false
    var texture := load_wasp_skin_texture(skin_index)
    if texture == null:
        return false
    var leg_texture := load_wasp_leg_skin_texture(skin_index)
    if leg_texture == null:
        leg_texture = texture
    _apply_wasp_textures_to_meshes(model_root, texture, leg_texture)
    return true


func align_model_instance_to_ground(model_root: Node3D, ground_y: float = 0.0) -> void:
    var bounds := get_model_global_bounds(model_root)
    if bounds.size == Vector3.ZERO:
        return

    var lift := ground_y - bounds.position.y
    if is_zero_approx(lift):
        return
    model_root.global_position.y += lift


func align_model_origin_to_ground(model_root: Node3D, pivot: Vector3, ground_y: float, origin_ground_height: float) -> void:
    var y_scale := model_root.global_transform.basis.y.length()
    model_root.global_position = Vector3(
            pivot.x,
            ground_y + origin_ground_height * y_scale,
            pivot.z
    )


func get_model_global_bounds(model_root: Node3D) -> AABB:
    var state := {
        "has_bounds": false,
        "bounds": AABB()
    }
    _accumulate_mesh_bounds(model_root, state)
    return state["bounds"] if state["has_bounds"] else AABB()


func verify_required_assets() -> Array[String]:
    _ensure_built()
    var missing: Array[String] = []
    for entry_id: String in entries.keys():
        var entry: Resource = entries[entry_id]
        if not ResourceLoader.exists(entry.path) and not FileAccess.file_exists(entry.path):
            missing.append("%s -> %s" % [entry_id, entry.path])
        if not entry.animation_library_path.is_empty():
            if not ResourceLoader.exists(entry.animation_library_path) and not FileAccess.file_exists(entry.animation_library_path):
                missing.append("%s animation -> %s" % [entry_id, entry.animation_library_path])
    return missing


func all_entries() -> Array[Resource]:
    _ensure_built()
    var result: Array[Resource] = []
    for entry_id: String in entries.keys():
        result.append(entries[entry_id])
    return result


func _ensure_built() -> void:
    if entries.is_empty():
        rebuild()


func _accumulate_mesh_bounds(node: Node, state: Dictionary) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null:
        var mesh_bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
        if state["has_bounds"]:
            state["bounds"] = (state["bounds"] as AABB).merge(mesh_bounds)
        else:
            state["bounds"] = mesh_bounds
            state["has_bounds"] = true

    for child in node.get_children():
        _accumulate_mesh_bounds(child, state)


func _apply_texture_to_meshes(node: Node, texture: Texture2D, use_alpha: bool = false) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var base_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            var material := _build_textured_material(base_material, texture, use_alpha)
            mesh_instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_texture_to_meshes(child, texture, use_alpha)


func _apply_wasp_textures_to_meshes(node: Node, body_texture: Texture2D, leg_texture: Texture2D) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        var surface_count := mesh_instance.mesh.get_surface_count()
        for surface_index in range(surface_count):
            var base_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            # Surface 1 is the generated mirrored/lower-leg primitive split from wasp1.MDL triangles 79-95.
            var is_leg_surface := surface_count > 1 and surface_index > 0
            var texture := leg_texture if is_leg_surface else body_texture
            var material := _build_textured_material(base_material, texture, true)
            if is_leg_surface:
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mesh_instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_wasp_textures_to_meshes(child, body_texture, leg_texture)


func _build_textured_material(base_material: StandardMaterial3D, texture: Texture2D, use_alpha: bool) -> StandardMaterial3D:
    var material: StandardMaterial3D = null
    if base_material != null:
        material = base_material.duplicate() as StandardMaterial3D
    else:
        material = StandardMaterial3D.new()
    material.albedo_texture = texture
    if use_alpha:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        material.alpha_scissor_threshold = 0.5
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    return material


func _transform_aabb(transform: Transform3D, bounds: AABB) -> AABB:
    var points: Array[Vector3] = [
        bounds.position,
        bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
        bounds.position + Vector3(0.0, bounds.size.y, 0.0),
        bounds.position + Vector3(0.0, 0.0, bounds.size.z),
        bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
        bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
        bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
        bounds.position + bounds.size
    ]

    var transformed := AABB(transform * points[0], Vector3.ZERO)
    for index in range(1, points.size()):
        transformed = transformed.expand(transform * points[index])
    return transformed
