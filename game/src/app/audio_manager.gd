class_name AudioManager
extends Node
## Separate Music and SFX buses with independent volume settings.

const SFX := ["tap", "place", "counter", "invalid", "stage", "deliver", "win", "star",
	"lose", "restore", "undo", "warn"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX:
		var p := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	var m := "res://assets/audio/music_cafe.wav"
	if ResourceLoader.exists(m):
		var s: AudioStreamWAV = load(m)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2  # 16-bit mono frames
		_music.stream = s

func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")

func apply_settings(s: Dictionary) -> void:
	_set_vol("Music", float(s.music))
	_set_vol("SFX", float(s.sfx))
	if _music and _music.stream:
		if float(s.music) > 0.001 and not _music.playing:
			_music.play()
		elif float(s.music) <= 0.001 and _music.playing:
			_music.stop()

func _set_vol(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

func play(name: String, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var pl := _pool[_next]
	_next = (_next + 1) % _pool.size()
	pl.stream = _streams[name]
	pl.pitch_scale = pitch
	pl.play()
