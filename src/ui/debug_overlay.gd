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
    _append_score_lines(lines)
    if _player != null:
        var p := _player.global_position
        lines.append("Player: %.2f, %.2f, %.2f" % [p.x, p.y, p.z])
        if _player.has_method("get_health") and _player.has_method("get_max_health"):
            var health := float(_player.call("get_health"))
            var max_health := float(_player.call("get_max_health"))
            if is_equal_approx(health, roundf(health)):
                lines.append("Health: %d / %d" % [int(roundf(health)), int(roundf(max_health))])
            else:
                lines.append("Health: %.2f / %d" % [health, int(roundf(max_health))])
        if _player.has_method("get_lives") and _player.has_method("get_max_lives"):
            lines.append("Lives: %d / %d" % [int(_player.call("get_lives")), int(_player.call("get_max_lives"))])
        if _player.has_method("is_game_over") and bool(_player.call("is_game_over")):
            lines.append("State: Game Over")
        elif _player.has_method("is_dead") and bool(_player.call("is_dead")):
            lines.append("State: Dead")
        if _player.has_method("get_boost_capacity") and _player.has_method("get_boost_capacity_max"):
            lines.append("Boost: %.0f / %.0f" % [
                    float(_player.call("get_boost_capacity")),
                    float(_player.call("get_boost_capacity_max"))
            ])
        if _player.has_method("get_current_key_name"):
            lines.append("Key: %s" % String(_player.call("get_current_key_name")))
        lines.append("Wasps: %d" % _get_player_wasp_count())
    _label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
    if InputMap.has_action("debug_toggle") and event.is_action_pressed("debug_toggle"):
        visible = not visible


func _resolve_player() -> void:
    if not player_path.is_empty():
        _player = get_node_or_null(player_path) as Node3D
    if _player == null:
        _player = get_tree().get_first_node_in_group("player") as Node3D


func _get_player_wasp_count() -> int:
    if _player == null or not _player.has_method("get_wasp_inventory"):
        return 0
    var inventory: Node = _player.call("get_wasp_inventory")
    if inventory == null or not inventory.has_method("get_ammo_count"):
        return 0
    return int(inventory.call("get_ammo_count"))


func _append_score_lines(lines: Array[String]) -> void:
    var game := get_node_or_null("/root/Game")
    if game == null or not game.has_method("get_score_points") or not game.has_method("get_last_score_delta"):
        return
    lines.append("Score: %d" % int(game.call("get_score_points")))
    var last_delta := int(game.call("get_last_score_delta"))
    var sign := "+" if last_delta >= 0 else ""
    lines.append("Last pickup: %s%d" % [sign, last_delta])
