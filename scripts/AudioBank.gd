extends Node

var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _ambience: AudioStreamPlayer
var _streams: Dictionary = {}
var muted: bool = false

const SFX_FILES := {
	"rifle": "res://assets/sfx/sfx_rifle.mp3",
	"shotgun": "res://assets/sfx/sfx_shotgun.mp3",
	"pistol": "res://assets/sfx/sfx_pistol.mp3",
	"reload": "res://assets/sfx/sfx_reload.mp3",
	"hit": "res://assets/sfx/sfx_hit.mp3",
	"headshot": "res://assets/sfx/sfx_headshot.mp3",
	"explosion": "res://assets/sfx/sfx_explosion.mp3",
	"enemy_fire": "res://assets/sfx/sfx_enemy_fire.mp3",
	"hurt": "res://assets/sfx/sfx_hurt.mp3",
}

func _ready() -> void:
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)

	for key in SFX_FILES.keys():
		var path: String = SFX_FILES[key]
		if ResourceLoader.exists(path):
			var s := load(path)
			if s is AudioStream:
				_streams[key] = s

	if not _streams.has("rifle"):
		_streams["rifle"] = _make_punch(180.0, 45.0, 0.14, 0.55)
	if not _streams.has("shotgun"):
		_streams["shotgun"] = _make_punch(130.0, 32.0, 0.28, 0.70)
	if not _streams.has("pistol"):
		_streams["pistol"] = _make_punch(260.0, 70.0, 0.11, 0.45)
	if not _streams.has("reload"):
		_streams["reload"] = _make_tone(640.0, 880.0, 0.12, 0.25)
	if not _streams.has("hit"):
		_streams["hit"] = _make_tone(1250.0, 900.0, 0.05, 0.30)
	if not _streams.has("headshot"):
		_streams["headshot"] = _make_tone(1500.0, 2100.0, 0.09, 0.38)
	if not _streams.has("explosion"):
		_streams["explosion"] = _make_punch(90.0, 22.0, 0.55, 0.85)
	if not _streams.has("enemy_fire"):
		_streams["enemy_fire"] = _make_punch(220.0, 60.0, 0.12, 0.30)
	if not _streams.has("hurt"):
		_streams["hurt"] = _make_punch(140.0, 40.0, 0.18, 0.50)

	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -14.0
	add_child(_ambience)
	if ResourceLoader.exists("res://assets/sfx/sfx_ambience.mp3"):
		var amb := load("res://assets/sfx/sfx_ambience.mp3")
		if amb is AudioStreamMP3:
			(amb as AudioStreamMP3).loop = true
			_ambience.stream = amb
			_ambience.play()

func play(key: String, vol_db: float = -2.0, pitch_jitter: float = 0.05) -> void:
	if muted or not _streams.has(key):
		return
	var p := _players[_next_idx]
	_next_idx = (_next_idx + 1) % _players.size()
	p.stream = _streams[key]
	p.volume_db = vol_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()

func _make_punch(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / float(rate)
		var env := pow(1.0 - t, 2.2)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.45)
		var s := (sin(phase) * 0.45 + lp * 0.55) * env * amp
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _make_tone(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / float(rate)
		var env := (1.0 - t) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(sin(phase) * env * amp, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
