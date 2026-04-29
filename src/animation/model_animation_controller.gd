extends Node
class_name ModelAnimationController

const ACTION_LIBRARY_NAME := "actions"
const DEFAULT_BLEND_SECONDS := 0.18

@export var animation_library_path: String = ""
@export var default_action: String = "stand"
@export var default_blend_seconds: float = DEFAULT_BLEND_SECONDS
@export var model_root_path: NodePath
@export var autoplay_on_ready: bool = true

var animation_player: AnimationPlayer

var _current_action: StringName = &""
var _current_speed: float = 1.0


func _ready() -> void:
    if animation_player != null or animation_library_path.is_empty():
        return
    var model_root := _resolve_model_root()
    if model_root != null:
        configure(model_root, animation_library_path, default_action, autoplay_on_ready)


func configure(model_root: Node, library_path: String, initial_action: String = "stand", autoplay: bool = true) -> bool:
    animation_library_path = library_path
    default_action = initial_action
    animation_player = _find_animation_player(model_root)
    if animation_player == null:
        push_warning("Animated model has no AnimationPlayer: %s" % model_root.name)
        return false
    if animation_library_path.is_empty():
        return false

    var library := load(animation_library_path) as AnimationLibrary
    if library == null:
        push_warning("Unable to load generated animation library: %s" % animation_library_path)
        return false

    if animation_player.has_animation_library(ACTION_LIBRARY_NAME):
        animation_player.remove_animation_library(ACTION_LIBRARY_NAME)
    var err := animation_player.add_animation_library(ACTION_LIBRARY_NAME, library)
    if err != OK:
        push_warning("Unable to add generated animation library %s: %s" % [animation_library_path, error_string(err)])
        return false

    if autoplay and not default_action.is_empty():
        play_action(default_action)
    return true


func play_action(action: StringName, blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false, restart: bool = false) -> bool:
    if animation_player == null:
        return false

    var animation_name := _qualified_action_name(action)
    if not animation_player.has_animation(animation_name):
        return false

    if _current_action == action and is_equal_approx(_current_speed, custom_speed) and not restart:
        return true
    if _current_action == action and not restart:
        _current_speed = custom_speed
        animation_player.speed_scale = custom_speed
        return true

    _current_action = action
    _current_speed = custom_speed
    var resolved_blend := default_blend_seconds if blend < 0.0 else blend
    animation_player.speed_scale = custom_speed
    animation_player.play(animation_name, resolved_blend, 1.0, from_end)
    return true


func has_action(action: StringName) -> bool:
    if animation_player == null:
        return false
    return animation_player.has_animation(_qualified_action_name(action))


func is_playing() -> bool:
    return animation_player != null and animation_player.is_playing()


func get_current_action() -> StringName:
    return _current_action


func _qualified_action_name(action: StringName) -> StringName:
    return StringName("%s/%s" % [ACTION_LIBRARY_NAME, action])


func _resolve_model_root() -> Node:
    if not model_root_path.is_empty():
        return get_node_or_null(model_root_path)
    return get_parent()


func _find_animation_player(node: Node) -> AnimationPlayer:
    var player := node as AnimationPlayer
    if player != null:
        return player

    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null
