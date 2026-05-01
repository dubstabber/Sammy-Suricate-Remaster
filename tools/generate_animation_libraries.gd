extends SceneTree

const OUTPUT_DIR := "res://assets/animations"
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const GODOT_PLAYBACK_SPEED_CORRECTION := 1.12
const PLACEHOLDER_CLIPS := {
    "base": true,
    "walk_trans": true,
    "toto": true
}

const MODEL_CONFIGS := [
    {
        "name": "suricat1",
        "gltf_path": "res://assets/models/suricat1/suricat1_animated.gltf",
        "output_path": "res://assets/animations/suricat1_clips.tres",
        "looping": ["stand", "walkA", "walkB", "turn", "kaputt", "loopjambes", "finkaputt"],
        "step_speeds": {
            "stand": 2.0,
            "sautA": 30.0,
            "sautB": 14.0,
            "sautC": 14.0,
            "tirA": 20.0,
            "tirB": 20.0,
            "turn": 14.0,
            "kaputt": 3.0,
            "finkaputt": 3.0,
            "Iwin": 3.0,
            "loopjambes": 2.0,
            "salut": 3.0
        },
        "duration_overrides": {
            "walkA": 1.0,
            "walkAB": 0.25,
            "walkB": 1.0,
            "death": 1.4
        }
    },
    {
        "name": "rasta",
        "gltf_path": "res://assets/models/rasta/rasta_animated.gltf",
        "output_path": "res://assets/animations/rasta_clips.tres",
        "looping": ["stand", "AltStand", "walk", "run"],
        "step_speeds": {
            "stand": 3.0,
            "AltStand": 3.0,
            "rugit": 4.0,
            "attack": 6.0,
            "hit": 10.0,
            "walk": 0.82,
            "run": 0.3,
            "death": 4.0
        }
    },
    {
        "name": "punk",
        "gltf_path": "res://assets/models/Punk/Punk_animated.gltf",
        "output_path": "res://assets/animations/punk_clips.tres",
        "looping": ["stand", "AltStand", "walk", "run"],
        "step_speeds": {
            "stand": 3.0,
            "AltStand": 3.0,
            "rugit": 4.0,
            "attack": 6.0,
            "hit": 10.0,
            "walk": 0.82,
            "run": 0.3,
            "death": 4.0
        }
    },
    {
        "name": "scorpion",
        "gltf_path": "res://assets/models/scorpion/scorpion_animated.gltf",
        "output_path": "res://assets/animations/scorpion_clips.tres",
        "looping": ["stand", "walk", "run"],
        "clip_name_map": {
            "Stand": "stand",
            "Rugit": "rugit",
            "Hit": "hit",
            "Attack": "attack",
            "Walk": "walk",
            "Run": "run",
            "Death": "death"
        },
        "step_speeds": {
            "stand": 3.0,
            "rugit": 4.0,
            "attack": 6.0,
            "hit": 10.0,
            "walk": 0.82,
            "run": 0.3,
            "death": 4.0
        }
    },
    {
        "name": "boost",
        "gltf_path": "res://assets/models/boost/boost_animated.gltf",
        "output_path": "res://assets/animations/boost_clips.tres",
        "looping": ["stand"],
        "duration_overrides": {
            "stand": 1.2
        }
    },
    {
        "name": "cactus1",
        "gltf_path": "res://assets/models/cactus1/cactus1_animated.gltf",
        "output_path": "res://assets/animations/cactus1_clips.tres",
        "looping": ["stand"],
        "duration_overrides": {
            "stand": 1.2
        }
    },
    {
        "name": "wasp1",
        "gltf_path": "res://assets/models/wasp1/wasp1_animated.gltf",
        "output_path": "res://assets/animations/wasp1_clips.tres",
        "looping": ["stand", "walk"],
        "step_speeds": {
            "stand": 3.0,
            "walk": 0.5,
            "death": 6.0
        }
    }
]

var _failed := false


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    for config in MODEL_CONFIGS:
        _generate_library(config)

    quit(1 if _failed else 0)


func _generate_library(config: Dictionary) -> void:
    var gltf_path := String(config["gltf_path"])
    var output_path := String(config["output_path"])
    var frame_names := _read_frame_names(gltf_path)
    if frame_names.is_empty():
        _fail("No GLTF frame names found in %s" % gltf_path)
        return

    var source_root := _load_source_scene(gltf_path)
    if source_root == null:
        _fail("Unable to instantiate %s" % gltf_path)
        return

    var source_player := _find_animation_player(source_root)
    if source_player == null:
        _fail("No AnimationPlayer found in %s" % gltf_path)
        source_root.free()
        return

    var source_animation_name := _find_source_animation_name(source_player)
    if String(source_animation_name).is_empty():
        _fail("No imported animation found in %s" % gltf_path)
        source_root.free()
        return

    var source_animation := source_player.get_animation(source_animation_name)
    var source_tracks := _collect_source_tracks(source_animation)
    if source_tracks.is_empty():
        _fail("No morph-target tracks found in %s" % gltf_path)
        source_root.free()
        return

    var fps := _read_animation_fps(gltf_path)
    var clips := _collect_frame_clips(frame_names)
    var library := AnimationLibrary.new()
    var looping: Dictionary = {}
    for clip_name in config.get("looping", []):
        looping[String(clip_name)] = true
    var clip_name_map := config.get("clip_name_map", {}) as Dictionary
    var step_speeds := config.get("step_speeds", {}) as Dictionary
    var duration_overrides := config.get("duration_overrides", {}) as Dictionary

    for clip in clips:
        var clip_name := _mapped_clip_name(String(clip["name"]), clip_name_map)
        if PLACEHOLDER_CLIPS.has(clip_name):
            continue

        var frame_count := int(clip["end"]) - int(clip["start"]) + 1
        var clip_length := _resolve_clip_length(clip_name, frame_count, fps, step_speeds, duration_overrides)
        var animation := _build_clip_animation(
                source_tracks,
                frame_names,
                int(clip["start"]),
                int(clip["end"]),
                clip_length,
                looping.has(clip_name)
        )
        library.add_animation(clip_name, animation)

    var err := ResourceSaver.save(library, output_path)
    source_root.free()
    if err != OK:
        _fail("Unable to save %s: %s" % [output_path, error_string(err)])
        return

    print("Generated %s with %d clips." % [output_path, library.get_animation_list().size()])


func _load_source_scene(gltf_path: String) -> Node:
    var scene := load(gltf_path) as PackedScene
    if scene == null:
        return null
    return scene.instantiate()


func _find_animation_player(node: Node) -> AnimationPlayer:
    var player := node as AnimationPlayer
    if player != null:
        return player

    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null


func _find_source_animation_name(player: AnimationPlayer) -> StringName:
    for animation_name in player.get_animation_list():
        if not String(animation_name).begins_with("RESET"):
            return animation_name
    return &""


func _read_frame_names(gltf_path: String) -> Array[String]:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(gltf_path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return []

    var document := parsed as Dictionary
    var animations := document.get("animations", []) as Array
    if animations.is_empty():
        return []

    var first_animation := animations[0] as Dictionary
    var extras := first_animation.get("extras", {}) as Dictionary
    var raw_names := extras.get("frameNames", []) as Array
    var names: Array[String] = []
    for raw_name in raw_names:
        names.append(String(raw_name))
    return names


func _read_animation_fps(gltf_path: String) -> float:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(gltf_path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return 10.0

    var document := parsed as Dictionary
    var animations := document.get("animations", []) as Array
    if animations.is_empty():
        return 10.0

    var first_animation := animations[0] as Dictionary
    var extras := first_animation.get("extras", {}) as Dictionary
    return float(extras.get("fps", 10.0))


func _collect_source_tracks(source_animation: Animation) -> Array[Dictionary]:
    var tracks: Array[Dictionary] = []
    for track_index in source_animation.get_track_count():
        var track_path := source_animation.track_get_path(track_index)
        tracks.append({
            "path": track_path,
            "type": source_animation.track_get_type(track_index),
            "interpolation": source_animation.track_get_interpolation_type(track_index),
            "frame_name": _track_frame_name(track_path)
        })
    return tracks


func _collect_frame_clips(frame_names: Array[String]) -> Array[Dictionary]:
    var clips: Array[Dictionary] = []
    var current_name := ""
    var start_index := 0

    for index in frame_names.size():
        var clip_name := _clip_name_for_frame(frame_names[index])
        if index == 0:
            current_name = clip_name
            continue
        if clip_name == current_name:
            continue

        clips.append({
            "name": current_name,
            "start": start_index,
            "end": index - 1
        })
        current_name = clip_name
        start_index = index

    if not frame_names.is_empty():
        clips.append({
            "name": current_name,
            "start": start_index,
            "end": frame_names.size() - 1
        })
    return clips


func _build_clip_animation(
        source_tracks: Array[Dictionary],
        frame_names: Array[String],
        start_index: int,
        end_index: int,
        clip_length: float,
        looping: bool
) -> Animation:
    var animation := Animation.new()
    var frame_count := end_index - start_index + 1
    animation.length = maxf(clip_length, 0.001)
    animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE

    for source_track in source_tracks:
        var target_track := animation.add_track(int(source_track["type"]))
        animation.track_set_path(target_track, source_track["path"] as NodePath)
        animation.track_set_interpolation_type(target_track, Animation.INTERPOLATION_LINEAR)
        _insert_track_keys(animation, target_track, String(source_track["frame_name"]), frame_names, start_index, end_index, looping)

    return animation


func _insert_track_keys(
        animation: Animation,
        target_track: int,
        track_frame_name: String,
        frame_names: Array[String],
        start_index: int,
        end_index: int,
        looping: bool
) -> void:
    var frame_count := end_index - start_index + 1
    var frame_duration := _frame_duration_for_clip(animation.length, frame_count, looping)
    for frame_index in range(start_index, end_index + 1):
        var local_time := float(frame_index - start_index) * frame_duration
        var value := 1.0 if frame_names[frame_index] == track_frame_name else 0.0
        animation.track_insert_key(target_track, local_time, value)
    if looping:
        var wrap_value := 1.0 if frame_names[start_index] == track_frame_name else 0.0
        animation.track_insert_key(target_track, animation.length, wrap_value)


func _frame_duration_for_clip(animation_length: float, frame_count: int, looping: bool) -> float:
    if looping:
        return animation_length / maxf(float(frame_count), 1.0)
    return animation_length / maxf(float(frame_count - 1), 1.0)


func _resolve_clip_length(
        clip_name: String,
        frame_count: int,
        fps: float,
        step_speeds: Dictionary,
        duration_overrides: Dictionary
) -> float:
    if duration_overrides.has(clip_name):
        return float(duration_overrides[clip_name]) / GODOT_PLAYBACK_SPEED_CORRECTION
    if step_speeds.has(clip_name):
        var step_speed := float(step_speeds[clip_name])
        if step_speed > 0.0:
            return 100.0 / (step_speed * ACKNEX_TIME_UNITS_PER_SECOND * GODOT_PLAYBACK_SPEED_CORRECTION)
    return (float(frame_count) / fps) / GODOT_PLAYBACK_SPEED_CORRECTION


func _track_frame_name(track_path: NodePath) -> String:
    var text := String(track_path)
    var colon_index := text.rfind(":")
    if colon_index < 0:
        return text
    return text.substr(colon_index + 1)


func _clip_name_for_frame(frame_name: String) -> String:
    var end_index := frame_name.length() - 1
    while end_index >= 0:
        var code := frame_name.unicode_at(end_index)
        if code < 48 or code > 57:
            break
        end_index -= 1
    return frame_name.substr(0, end_index + 1)


func _mapped_clip_name(clip_name: String, clip_name_map: Dictionary) -> String:
    if clip_name_map.is_empty():
        return clip_name
    if clip_name_map.has(clip_name):
        return String(clip_name_map[clip_name])
    var lowercase_name := clip_name.to_lower()
    if clip_name_map.has(lowercase_name):
        return String(clip_name_map[lowercase_name])
    return lowercase_name


func _fail(message: String) -> void:
    push_error(message)
    _failed = true
