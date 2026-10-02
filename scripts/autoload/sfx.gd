extends Node
## Gestor de efectos de sonido. Sfx.play("laser_l01", plane_pos) atenúa por distancia al jugador.
## Los .wav viven en res://assets/audio/sfx/ (generados por scripts/tools/gen_sfx.gd; reemplazables).

const DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 32
const HEAR_RANGE := 1500.0     # unidades de plano
const MIN_INTERVAL := 0.045    # evita que un mismo sonido se apile en el mismo instante
const MAX_SAME := 4

var volume_db := -4.0
var muted := false
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last: Dictionary = {}
var listener_pos := Vector2.ZERO
var has_listener := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := DIR + name + ".wav"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


## Reproduce un efecto. Si se da `pos` (plano) se atenúa por distancia al oyente (la nave).
func play(name: String, pos = null, vol: float = 0.0, pitch_var: float = 0.05) -> void:
	if muted:
		return
	var s := _stream(name)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < MIN_INTERVAL:
		return
	var db := volume_db + vol
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
	free.volume_db = db
	free.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	free.play()
