extends CanvasLayer

@export var player_path: NodePath

var _label: Label
var _player: Node3D


func _ready() -> void:
    layer = 20
    _label = Label.new()
    _label.position = Vector2(12.0, 12.0)
    add_child(_label)
    _resolve_player()


func _physics_process(_delta: float) -> void:
    if _player == null:
        _resolve_player()

    var lines: Array[String] = [
        "Sammy Suricate Remaster",
        "FPS: %d" % Engine.get_frames_per_second()
    ]
    if _player != null:
        var p := _player.global_position
        lines.append("Player: %.2f, %.2f, %.2f" % [p.x, p.y, p.z])
    _label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
    if InputMap.has_action("debug_toggle") and event.is_action_pressed("debug_toggle"):
        visible = not visible


func _resolve_player() -> void:
    if not player_path.is_empty():
        _player = get_node_or_null(player_path) as Node3D
    if _player == null:
        _player = get_tree().get_first_node_in_group("player") as Node3D
