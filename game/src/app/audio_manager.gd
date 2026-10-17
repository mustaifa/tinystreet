class_name AudioManager
extends Node
## Separate Music and SFX buses with independent volume settings.

const SFX := ["tap", "place", "counter", "invalid", "stage", "deliver", "win", "star",
	"lose", "restore", "undo", "warn", "combo", "coin", "bag", "unlock", "bell"]

var _streams := {}
var _db := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	reload_streams()
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.stream = _music_stream()

## Sounds come from the active skin ("sfx.<name>", "music.cafe"); anything the
## skin doesn't provide falls back to the built-in files in assets/audio.
func reload_streams() -> void:
	_streams.clear()
	_db.clear()
	for n in SFX:
		var s := ArtSkin.sound("sfx." + n)
		if s:
			_streams[n] = s
			_db[n] = ArtSkin.sound_db("sfx." + n)
			continue
		var p := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)

func _music_stream() -> AudioStream:
	var s := ArtSkin.sound("music.cafe")
	if s:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		return s
	# Looping is set in the import (edit/loop_mode=2, forward over the whole
	# file), which is correct for the QOA-compressed stream.
	var m := "res://assets/audio/music_cafe.wav"
	return load(m) as AudioStream if ResourceLoader.exists(m) else null

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
	pl.volume_db = float(_db.get(name, 0.0))
	pl.play()
