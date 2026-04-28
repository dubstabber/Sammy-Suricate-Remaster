extends Node

const SFX_POOL_SIZE := 6

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_index := 0


func _ready() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = "Master"
    add_child(_music_player)

    for index in SFX_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        player.name = "SfxPlayer%d" % index
        player.bus = "Master"
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


func play_sfx(asset_id: String) -> void:
    var stream := _load_stream(asset_id)
    if stream == null or _sfx_players.is_empty():
        return

    var player := _sfx_players[_next_sfx_index]
    _next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
    player.stream = stream
    player.play()


func _exit_tree() -> void:
    stop_music()
    for player in _sfx_players:
        player.stop()
        player.stream = null


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
