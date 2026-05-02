extends Node

const SFX_POOL_SIZE := 6
const SILENT_VOLUME_DB := -80.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_index := 0
var _music_volume := 1.0
var _sfx_volume := 1.0


func _ready() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = "Master"
    _music_player.volume_db = _volume_to_db(_music_volume)
    add_child(_music_player)

    for index in SFX_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        player.name = "SfxPlayer%d" % index
        player.bus = "Master"
        player.volume_db = _volume_to_db(_sfx_volume)
        add_child(player)
        _sfx_players.append(player)


func play_music(asset_id: String, loop: bool = true) -> void:
    var stream := _load_stream(asset_id)
    if stream == null:
        return
    if stream is AudioStreamOggVorbis:
        stream.loop = loop
    _music_player.stream = stream
    _music_player.play()


func stop_music() -> void:
    if _music_player != null:
        _music_player.stop()
        _music_player.stream = null


func stop_sfx() -> void:
    for player in _sfx_players:
        player.stop()
        player.stream = null


func set_music_volume_percent(value: float) -> void:
    _music_volume = clampf(value / 100.0, 0.0, 1.0)
    if _music_player != null:
        _music_player.volume_db = _volume_to_db(_music_volume)


func get_music_volume_percent() -> float:
    return _music_volume * 100.0


func set_sfx_volume_percent(value: float) -> void:
    _sfx_volume = clampf(value / 100.0, 0.0, 1.0)
    for player in _sfx_players:
        player.volume_db = _volume_to_db(_sfx_volume)


func get_sfx_volume_percent() -> float:
    return _sfx_volume * 100.0


func play_sfx(asset_id: String) -> void:
    var stream := _load_stream(asset_id)
    if stream == null or _sfx_players.is_empty():
        return

    var player := _sfx_players[_next_sfx_index]
    _next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
    player.volume_db = _volume_to_db(_sfx_volume)
    player.stream = stream
    player.play()


func _exit_tree() -> void:
    stop_music()
    stop_sfx()


func _load_stream(asset_id: String) -> AudioStream:
    var assets := get_node_or_null("/root/Assets")
    if assets == null:
        push_warning("Audio service cannot find Assets autoload.")
        return null
    var resource: Resource = assets.load_asset(asset_id)
    if resource is AudioStream:
        return resource
    push_warning("Asset is not an audio stream: %s" % asset_id)
    return null


func _volume_to_db(linear_volume: float) -> float:
    if linear_volume <= 0.0:
        return SILENT_VOLUME_DB
    return linear_to_db(clampf(linear_volume, 0.0, 1.0))
