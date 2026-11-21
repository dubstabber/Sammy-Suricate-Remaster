extends Node

const SFX_POOL_SIZE := 6
const SILENT_VOLUME_DB := -80.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const DEFAULT_SPATIAL_WDL_RANGE_UNITS := 1000.0
const MIN_SPATIAL_MAX_DISTANCE := 0.01
const SPATIAL_REFERENCE_DISTANCE_RATIO := 0.5
const MIN_SPATIAL_UNIT_SIZE := 1.0
const SPATIAL_VOLUME_BOOST_DB := 6.0
## A5 engine sound volume steps (sammypolish.exe 0x488BC0): DirectSound
## attenuation in hundredths of a dB for the 64 levels a WDL volume maps to.
const WDL_VOLUME_STEP_CENTIBELS := [
    -10000, -4143, -3449, -3044, -2756, -2533, -2351, -2197, -2063, -1945, -1840, -1745, -1658, -1578, -1504, -1435,
    -1370, -1309, -1252, -1198, -1147, -1098, -1052, -1007, -965, -924, -885, -847, -810, -775, -741, -709,
    -677, -646, -616, -587, -559, -532, -505, -479, -454, -429, -405, -381, -358, -336, -314, -292,
    -271, -251, -231, -211, -191, -172, -154, -135, -117, -100, -82, -65, -48, -32, -16, 0,
]
## The engine scales a WDL volume by Sound_Vol (the options sound slider,
## 0..100) and shifts it right by 7 to pick one of the 64 steps.
## TUNE_SOUND frequency: value * 10 / 1024 of the sample rate, clamped to 100..100000 Hz.
const WDL_FREQUENCY_SCALE := 10.0 / 1024.0
const WDL_MIN_FREQUENCY_HZ := 100.0
const WDL_MAX_FREQUENCY_HZ := 100000.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _spatial_sfx_players: Array[AudioStreamPlayer3D] = []
var _next_sfx_index := 0
var _music_volume := 1.0
var _sfx_volume := 1.0
var _next_spatial_sfx_id := 0
var _tuned_players := {}
var _next_tuned_handle := 1


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
    for player in _spatial_sfx_players.duplicate():
        if is_instance_valid(player):
            player.stop()
            player.stream = null
            player.queue_free()
    _spatial_sfx_players.clear()
    for handle: int in _tuned_players.keys():
        stop_tuned_sfx(handle)


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
    for player in _spatial_sfx_players:
        if is_instance_valid(player):
            player.volume_db = _spatial_volume_db()
    for handle: int in _tuned_players:
        var tuned := _tuned_players[handle] as AudioStreamPlayer
        if tuned != null and is_instance_valid(tuned):
            _apply_tuning(tuned, 0.0, 0.0)


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


## WDL `play_sound snd, volume` followed by optional `tune_sound handle,
## volume, frequency`: returns a handle for tune_sfx / stop_tuned_sfx.
func play_sfx_tuned(asset_id: String, wdl_volume: float = 100.0, wdl_frequency: float = 0.0) -> int:
    var stream := _load_stream(asset_id)
    if stream == null:
        return 0
    var player := AudioStreamPlayer.new()
    var handle := _next_tuned_handle
    _next_tuned_handle += 1
    player.name = "TunedSfxPlayer%d" % handle
    player.bus = "Master"
    player.stream = stream
    player.set_meta(&"wdl_volume", wdl_volume)
    add_child(player)
    _tuned_players[handle] = player
    player.finished.connect(_on_tuned_sfx_finished.bind(handle), CONNECT_ONE_SHOT)
    _apply_tuning(player, wdl_volume, wdl_frequency)
    player.play()
    return handle


## WDL TUNE_SOUND (sammypolish.exe sub_41D900): a volume or frequency of 0
## leaves that property unchanged.
func tune_sfx(handle: int, wdl_volume: float, wdl_frequency: float) -> bool:
    var player := _tuned_players.get(handle, null) as AudioStreamPlayer
    if player == null or not is_instance_valid(player):
        return false
    _apply_tuning(player, wdl_volume, wdl_frequency)
    return true


func stop_tuned_sfx(handle: int) -> void:
    var player := _tuned_players.get(handle, null) as AudioStreamPlayer
    _tuned_players.erase(handle)
    if player != null and is_instance_valid(player):
        player.stop()
        player.queue_free()


func is_tuned_sfx_playing(handle: int) -> bool:
    var player := _tuned_players.get(handle, null) as AudioStreamPlayer
    return player != null and is_instance_valid(player) and player.playing


func get_tuned_sfx_player(handle: int) -> AudioStreamPlayer:
    return _tuned_players.get(handle, null) as AudioStreamPlayer


## dB of a WDL sound volume at a Sound_Vol master volume (both 0..100).
static func wdl_volume_db(wdl_volume: float, master_volume_percent: float = 100.0) -> float:
    if wdl_volume <= 0.0 or master_volume_percent <= 0.0:
        return SILENT_VOLUME_DB
    var step := clampi(int(wdl_volume * master_volume_percent) >> 7, 1, WDL_VOLUME_STEP_CENTIBELS.size() - 1)
    return float(WDL_VOLUME_STEP_CENTIBELS[step]) / 100.0


## Playback pitch of a WDL TUNE_SOUND frequency for a stream of `mix_rate` Hz.
static func wdl_pitch_scale(wdl_frequency: float, mix_rate: float) -> float:
    var rate := maxf(mix_rate, 1.0)
    var hz := clampf(wdl_frequency * WDL_FREQUENCY_SCALE * rate, WDL_MIN_FREQUENCY_HZ, WDL_MAX_FREQUENCY_HZ)
    return maxf(hz / rate, 0.01)


func _apply_tuning(player: AudioStreamPlayer, wdl_volume: float, wdl_frequency: float) -> void:
    if wdl_volume > 0.0:
        player.set_meta(&"wdl_volume", wdl_volume)
    var volume := float(player.get_meta(&"wdl_volume", 100.0))
    player.volume_db = wdl_volume_db(volume, _sfx_volume * 100.0)
    if wdl_frequency > 0.0:
        var mix_rate := 22050.0
        if player.stream is AudioStreamWAV:
            mix_rate = float((player.stream as AudioStreamWAV).mix_rate)
        player.pitch_scale = wdl_pitch_scale(wdl_frequency, mix_rate)


func _on_tuned_sfx_finished(handle: int) -> void:
    var player := _tuned_players.get(handle, null) as AudioStreamPlayer
    _tuned_players.erase(handle)
    if player != null and is_instance_valid(player):
        player.queue_free()


func play_spatial_sfx(asset_id: String, source: Node3D, wdl_range_units: float = DEFAULT_SPATIAL_WDL_RANGE_UNITS) -> void:
    if source == null:
        play_sfx(asset_id)
        return
    play_sfx_at(asset_id, source.global_position, wdl_range_units)


func play_sfx_at(asset_id: String, world_position: Vector3, wdl_range_units: float = DEFAULT_SPATIAL_WDL_RANGE_UNITS) -> void:
    var stream := _load_stream(asset_id)
    if stream == null:
        return

    var player := AudioStreamPlayer3D.new()
    player.name = "SpatialSfxPlayer%d" % _next_spatial_sfx_id
    _next_spatial_sfx_id += 1
    player.bus = "Master"
    player.volume_db = _spatial_volume_db()
    player.stream = stream
    player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    player.max_db = SPATIAL_VOLUME_BOOST_DB
    player.max_distance = _spatial_max_distance(wdl_range_units)
    player.unit_size = maxf(player.max_distance * SPATIAL_REFERENCE_DISTANCE_RATIO, MIN_SPATIAL_UNIT_SIZE)
    add_child(player)
    player.global_position = world_position
    _spatial_sfx_players.append(player)
    player.finished.connect(_on_spatial_sfx_finished.bind(player), CONNECT_ONE_SHOT)
    player.play()


func _exit_tree() -> void:
    stop_music()
    stop_sfx()


func _on_spatial_sfx_finished(player: AudioStreamPlayer3D) -> void:
    _spatial_sfx_players.erase(player)
    if is_instance_valid(player):
        player.queue_free()


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


func _spatial_max_distance(wdl_range_units: float) -> float:
    return maxf(wdl_range_units * ACKNEX_TO_GODOT_SCALE, MIN_SPATIAL_MAX_DISTANCE)


func _spatial_volume_db() -> float:
    if _sfx_volume <= 0.0:
        return SILENT_VOLUME_DB
    return _volume_to_db(_sfx_volume) + SPATIAL_VOLUME_BOOST_DB
