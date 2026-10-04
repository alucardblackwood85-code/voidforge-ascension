extends Node
## Audio del juego: efectos (Sfx.play), voces de la IA de la nave (Sfx.voice) y buses de volumen.
## Buses: Master → Music, SFX, Lasers, Voice. Los volúmenes se guardan en el perfil (0..1).
## Los .wav viven en res://assets/audio/{sfx,voice}/ (reemplazables por archivos con el mismo nombre).

const DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"
const BUSES := ["Music", "SFX", "Lasers", "Voice"]
const POOL_SIZE := 32
const HEAR_RANGE := 1500.0     # unidades de plano
const MIN_INTERVAL := 0.045    # evita que un mismo sonido se apile en el mismo instante
const MAX_SAME := 4

var _players: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _streams: Dictionary = {}
var _last: Dictionary = {}
var listener_pos := Vector2.ZERO
var has_listener := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	apply_volumes()


## Aplica los volúmenes del perfil a los buses.
func apply_volumes() -> void:
	var a: Dictionary = GameState.data["settings"]["audio"]
	_set_bus("Master", a.get("master", 0.8))
	_set_bus("Music", a.get("music", 0.55))
	_set_bus("SFX", a.get("sfx", 0.8))
	_set_bus("Lasers", a.get("lasers", 0.6))
	_set_bus("Voice", a.get("voice", 0.9))


func _set_bus(name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func set_volume(key: String, linear: float) -> void:
	GameState.data["settings"]["audio"][key] = clampf(linear, 0.0, 1.0)
	apply_volumes()


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


## Reproduce un efecto. Si se da `pos` (plano) se atenúa por distancia al oyente (la nave).
func play(name: String, pos = null, vol: float = 0.0, pitch_var: float = 0.05, pitch: float = 1.0) -> void:
	var s := _stream(DIR + name + ".wav")
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < MIN_INTERVAL:
		return
	var db := vol
	if pos != null and has_listener:
		var d: float = (pos as Vector2).distance_to(listener_pos)
		if d > HEAR_RANGE:
			return
		db += linear_to_db(clampf(1.0 - d / HEAR_RANGE, 0.05, 1.0))
	var same := 0
	var free: AudioStreamPlayer = null
	for p in _players:
		if p.playing:
			if p.stream == s:
				same += 1
		elif free == null:
			free = p
	if same >= MAX_SAME:
		return
	if free == null:
		free = _players[randi() % POOL_SIZE]
	_last[name] = now
	free.stream = s
	free.bus = "Lasers" if name.begins_with("laser_") else "SFX"
	free.volume_db = db
	free.pitch_scale = pitch + randf_range(-pitch_var, pitch_var)
	free.play()


## Voz de la IA de la nave. No interrumpe una frase en curso salvo `urgent`.
func voice(id: String, urgent: bool = false) -> void:
	var s := _stream(VOICE_DIR + id + ".wav")
	if s == null or (_voice.playing and not urgent):
		return
	_voice.stream = s
	_voice.play()
