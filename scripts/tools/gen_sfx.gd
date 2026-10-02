extends SceneTree
## Sintetizador procedural de efectos de sonido (estilo sfxr). Genera assets/audio/sfx/*.wav.
## Uso: godot --headless --script res://scripts/tools/gen_sfx.gd
## Cada sonido = capas {w: onda, f0→f1: barrido Hz, t: inicio, d: duración, v: volumen, a: ataque,
## k: caída (exp), vib/vd: vibrato Hz/profundidad, lp: filtro paso bajo Hz, hp: paso alto}.
## Opciones globales: drive (distorsión), echo [retardo s, realimentación, repeticiones].

const SR := 44100
const OUT_DIR := "res://assets/audio/sfx/"


func L(w: String, f0: float, f1: float, d: float, v: float = 1.0, extra: Dictionary = {}) -> Dictionary:
	var l := {"w": w, "f0": f0, "f1": f1, "d": d, "v": v, "t": 0.0, "a": 0.004, "k": 4.0}
	l.merge(extra, true)
	return l


func sounds() -> Dictionary:
	var base := {
		# --- Láseres del jugador: cada uno con firma propia (19.3) ---
		"laser_l01": {"layers": [L("square", 980, 260, 0.16, 0.6, {"k": 5.0, "lp": 5000}), L("sine", 1960, 520, 0.08, 0.3)]},
		"laser_l02": {"layers": [L("square", 1300, 600, 0.07, 0.5, {"k": 6.0, "lp": 6000}), L("square", 1250, 560, 0.07, 0.5, {"t": 0.045, "k": 6.0, "lp": 6000})]},
		"laser_l03": {"layers": [L("sine", 2600, 1900, 0.11, 0.7, {"k": 7.0}), L("noise", 6000, 6000, 0.03, 0.15, {"hp": 3000})]},
		"laser_l04": {"layers": [L("tri", 760, 330, 0.13, 0.8, {"k": 5.0}), L("noise", 3000, 3000, 0.015, 0.4, {"lp": 6000})]},
		"laser_l05": {"layers": [L("saw", 520, 190, 0.26, 0.55, {"vib": 38, "vd": 0.18, "lp": 3500, "k": 3.0}), L("square", 1040, 380, 0.2, 0.2, {"vib": 38, "vd": 0.2})]},
		"laser_l06": {"layers": [L("saw", 340, 140, 0.24, 0.5, {"lp": 1800, "k": 3.0}), L("noise", 2500, 600, 0.26, 0.45, {"lp": 2200, "k": 2.5})], "drive": 1.6},
		"laser_l07": {"layers": [L("sine", 1850, 1650, 0.2, 0.55, {"vib": 22, "vd": 0.04, "a": 0.02, "k": 3.0}), L("sine", 3700, 3300, 0.2, 0.2, {"vib": 31, "vd": 0.05, "a": 0.02})]},
		"laser_l08": {"layers": [L("noise", 5000, 800, 0.2, 0.7, {"lp": 4000, "k": 5.0}), L("square", 620, 180, 0.16, 0.4, {"k": 5.0})]},
		"laser_l09": {"layers": [L("noise", 4000, 4000, 0.3, 0.55, {"lp": 5000, "vib": 60, "vd": 0.9, "k": 3.0}), L("square", 900, 300, 0.3, 0.3, {"vib": 47, "vd": 0.5, "k": 3.0})], "drive": 1.4},
		"laser_l10": {"layers": [L("saw", 230, 55, 0.5, 0.7, {"lp": 1400, "k": 2.5}), L("noise", 1500, 200, 0.45, 0.5, {"lp": 1200, "k": 3.0}), L("sine", 110, 40, 0.5, 0.6, {"k": 2.0})], "drive": 1.8},
		"laser_l11": {"layers": [L("sine", 1400, 3200, 0.15, 0.6, {"k": 4.0}), L("square", 700, 1600, 0.15, 0.2, {"lp": 6000, "k": 4.0})]},
		"laser_l12": {"layers": [L("sine", 660, 660, 0.35, 0.5, {"k": 2.5}), L("sine", 990, 990, 0.35, 0.35, {"k": 2.8}), L("tri", 1320, 1250, 0.2, 0.2)]},
		"laser_l13": {"layers": [L("saw", 1300, 90, 0.6, 0.6, {"lp": 4000, "k": 2.0}), L("noise", 6000, 600, 0.6, 0.35, {"lp": 3500, "k": 2.0}), L("sine", 160, 60, 0.6, 0.5, {"k": 2.0})], "drive": 1.5},
		"laser_l14": {"layers": [L("square", 210, 190, 0.25, 0.4, {"lp": 1600, "k": 3.0}), L("square", 214, 194, 0.25, 0.4, {"lp": 1600, "k": 3.0})]},
		"laser_l15": {"layers": [L("sine", 90, 38, 0.55, 0.9, {"k": 2.0}), L("noise", 300, 2500, 0.55, 0.35, {"lp": 1800, "a": 0.2, "k": 1.5})]},
		"laser_l16": {"layers": [L("sine", 1100, 520, 0.12, 0.6, {"k": 5.0})], "echo": [0.08, 0.5, 3]},
		"laser_l17": {"layers": [L("tri", 620, 410, 0.2, 0.45), L("tri", 780, 520, 0.2, 0.4), L("tri", 930, 620, 0.2, 0.35)]},
		"laser_l18": {"layers": [L("saw", 420, 48, 0.55, 0.7, {"lp": 2200, "k": 2.2}), L("noise", 2000, 200, 0.5, 0.4, {"lp": 1500})], "drive": 3.0},
		"laser_drone": {"layers": [L("sine", 1500, 900, 0.07, 0.5, {"k": 6.0}), L("square", 3000, 1800, 0.04, 0.12)]},

		# --- Alienígenas: disparos y habilidades por arquetipo ---
		"e_shot_light": {"layers": [L("square", 520, 240, 0.13, 0.5, {"lp": 3000, "k": 5.0})]},
		"e_shot_swarm": {"layers": [L("square", 760, 1250, 0.07, 0.4, {"lp": 4000, "k": 6.0})]},
		"e_shot_bio": {"layers": [L("sine", 300, 600, 0.12, 0.6, {"vib": 30, "vd": 0.3}), L("noise", 800, 800, 0.1, 0.3, {"lp": 900})]},
		"e_shot_crystal": {"layers": [L("sine", 2200, 2800, 0.1, 0.45, {"k": 5.0}), L("sine", 3300, 4200, 0.08, 0.25)]},
		"e_shot_void": {"layers": [L("saw", 300, 120, 0.16, 0.5, {"lp": 1200, "vib": 12, "vd": 0.3})]},
		"e_heavy": {"layers": [L("saw", 190, 80, 0.32, 0.65, {"lp": 1300, "k": 3.0}), L("noise", 900, 200, 0.25, 0.4, {"lp": 900})], "drive": 1.5},
		"e_charge": {"layers": [L("saw", 90, 620, 0.9, 0.45, {"a": 0.6, "k": 0.5, "lp": 2500}), L("square", 45, 310, 0.9, 0.25, {"a": 0.6, "k": 0.5, "lp": 1200})]},
		"e_dash": {"layers": [L("noise", 3500, 400, 0.45, 0.6, {"lp": 3000, "a": 0.03, "k": 3.0})]},
		"e_heal": {"layers": [L("sine", 520, 520, 0.12, 0.4), L("sine", 660, 660, 0.12, 0.4, {"t": 0.08}), L("sine", 880, 880, 0.18, 0.4, {"t": 0.16})]},
		"e_arm": {"layers": [L("square", 1050, 1050, 0.06, 0.4), L("square", 1050, 1050, 0.06, 0.4, {"t": 0.3}), L("square", 1400, 1400, 0.08, 0.5, {"t": 0.6})]},
		"e_launch": {"layers": [L("sine", 140, 60, 0.18, 0.8, {"k": 4.0}), L("sine", 1800, 600, 0.6, 0.25, {"t": 0.08, "k": 1.2})]},
		"e_spawn": {"layers": [L("sine", 160, 320, 0.45, 0.6, {"vib": 9, "vd": 0.25, "a": 0.08, "k": 2.0}), L("noise", 600, 300, 0.4, 0.3, {"lp": 700})]},
		"e_drain": {"layers": [L("saw", 140, 110, 0.7, 0.4, {"vib": 18, "vd": 0.2, "lp": 900, "a": 0.1, "k": 1.5}), L("sine", 880, 440, 0.7, 0.2, {"a": 0.1})]},
		"e_phase": {"layers": [L("noise", 600, 6000, 0.4, 0.4, {"lp": 5000, "a": 0.3, "k": 0.8}), L("sine", 400, 1600, 0.4, 0.3, {"a": 0.3, "k": 0.8})]},
		"e_snipe_charge": {"layers": [L("sine", 600, 2400, 1.3, 0.35, {"a": 1.1, "k": 0.4}), L("square", 300, 1200, 1.3, 0.1, {"a": 1.1, "k": 0.4, "lp": 3000})]},
		"e_snipe_fire": {"layers": [L("noise", 7000, 2000, 0.25, 0.8, {"lp": 7000, "k": 6.0}), L("saw", 1800, 200, 0.3, 0.5, {"k": 4.0})], "drive": 1.6},
		"e_reflect": {"layers": [L("sine", 1700, 1700, 0.4, 0.5, {"k": 3.0}), L("sine", 2550, 2550, 0.4, 0.3, {"k": 3.5}), L("sine", 3400, 3400, 0.3, 0.2)]},
		"e_pulse": {"layers": [L("sine", 120, 60, 0.6, 0.8, {"vib": 6, "vd": 0.3, "k": 2.0}), L("noise", 400, 200, 0.5, 0.3, {"lp": 500})]},
		"e_nova": {"layers": [L("saw", 80, 900, 0.5, 0.5, {"a": 0.4, "k": 0.6, "lp": 3000}), L("noise", 4000, 300, 0.6, 0.6, {"t": 0.45, "lp": 3000, "k": 3.0})], "drive": 1.5},

		# --- Explosiones e impactos ---
		"explosion_s": {"layers": [L("noise", 3000, 300, 0.35, 0.8, {"lp": 2500, "k": 4.0}), L("sine", 160, 50, 0.3, 0.6)], "drive": 1.5},
		"explosion_m": {"layers": [L("noise", 2500, 200, 0.6, 0.9, {"lp": 2000, "k": 3.0}), L("sine", 120, 35, 0.5, 0.8)], "drive": 2.0},
		"explosion_l": {"layers": [L("noise", 2000, 120, 1.1, 1.0, {"lp": 1600, "k": 2.2}), L("sine", 90, 28, 0.9, 0.9, {"k": 2.0})], "drive": 2.2, "echo": [0.12, 0.3, 2]},
		"ship_explode": {"layers": [L("noise", 3000, 90, 1.5, 1.0, {"lp": 2200, "k": 2.0}), L("sine", 110, 26, 1.2, 1.0, {"k": 1.8}), L("noise", 6000, 1500, 0.2, 0.6, {"lp": 7000, "k": 6.0}), L("saw", 70, 30, 0.9, 0.4, {"lp": 300, "t": 0.05, "k": 2.0}), L("noise", 1200, 300, 0.8, 0.4, {"t": 0.25, "lp": 1000, "k": 3.0})], "drive": 2.4, "echo": [0.14, 0.28, 2]},
		"hit_shield": {"layers": [L("sine", 900, 1300, 0.12, 0.35, {"vib": 50, "vd": 0.2, "k": 5.0}), L("noise", 6000, 6000, 0.06, 0.15, {"hp": 3000})]},
		"hit_hull": {"layers": [L("noise", 1800, 300, 0.18, 0.7, {"lp": 1500, "k": 5.0}), L("square", 140, 70, 0.15, 0.4, {"lp": 800})], "drive": 1.8},
		"hit_enemy": {"layers": [L("noise", 4000, 2000, 0.05, 0.35, {"lp": 6000, "k": 8.0})]},

		# --- Jugador y sistema ---
		"pickup": {"layers": [L("sine", 1300, 1300, 0.05, 0.4), L("sine", 1750, 1750, 0.08, 0.4, {"t": 0.045})]},
		"pickup_rare": {"layers": [L("sine", 1046, 1046, 0.1, 0.4), L("sine", 1318, 1318, 0.1, 0.4, {"t": 0.07}), L("sine", 1568, 1568, 0.1, 0.4, {"t": 0.14}), L("sine", 2093, 2093, 0.25, 0.4, {"t": 0.21})]},
		"boost": {"layers": [L("noise", 800, 4000, 0.35, 0.6, {"lp": 3500, "a": 0.02, "k": 3.0}), L("sine", 200, 500, 0.3, 0.3)]},
		"ability": {"layers": [L("saw", 200, 800, 0.4, 0.4, {"lp": 3000, "k": 2.0}), L("sine", 400, 1600, 0.4, 0.4, {"k": 2.0})]},
		"drone_ability": {"layers": [L("square", 800, 1600, 0.15, 0.35, {"lp": 4000}), L("square", 1200, 2400, 0.15, 0.3, {"t": 0.1, "lp": 4000})]},
		"item_use": {"layers": [L("sine", 600, 900, 0.15, 0.5), L("sine", 900, 1350, 0.15, 0.4, {"t": 0.08})]},
		"deploy": {"layers": [L("square", 300, 150, 0.12, 0.5, {"lp": 1500}), L("square", 900, 900, 0.05, 0.3, {"t": 0.15})]},
		"alert": {"layers": [L("square", 700, 700, 0.25, 0.35, {"lp": 2500, "k": 0.5}), L("square", 520, 520, 0.25, 0.35, {"t": 0.27, "lp": 2500, "k": 0.5}), L("square", 700, 700, 0.25, 0.35, {"t": 0.54, "lp": 2500, "k": 0.5})]},
		"jackpot": {"layers": [L("sine", 784, 784, 0.08, 0.45), L("sine", 1046, 1046, 0.08, 0.45, {"t": 0.06}), L("sine", 1318, 1318, 0.08, 0.45, {"t": 0.12}), L("sine", 1568, 1568, 0.08, 0.45, {"t": 0.18}), L("sine", 2093, 2093, 0.5, 0.5, {"t": 0.24, "k": 2.0}), L("tri", 1046, 2093, 0.6, 0.25, {"t": 0.24})]},
		"objective": {"layers": [L("tri", 523, 523, 0.15, 0.5), L("tri", 659, 659, 0.15, 0.5, {"t": 0.13}), L("tri", 784, 784, 0.15, 0.5, {"t": 0.26}), L("tri", 1046, 1046, 0.45, 0.5, {"t": 0.39, "k": 2.0})]},
		"warp": {"layers": [L("sine", 200, 2000, 1.0, 0.5, {"a": 0.6, "k": 0.8}), L("noise", 500, 6000, 1.0, 0.3, {"lp": 5000, "a": 0.6, "k": 0.8})]},
		"ui_click": {"layers": [L("square", 1800, 1200, 0.03, 0.25, {"lp": 6000, "k": 8.0})]},
		"ui_select": {"layers": [L("tri", 900, 1400, 0.06, 0.4, {"k": 5.0})]},
		"ui_error": {"layers": [L("square", 220, 180, 0.15, 0.35, {"lp": 1500}), L("square", 180, 150, 0.15, 0.35, {"t": 0.12, "lp": 1500})]},
		"craft": {"layers": [L("noise", 3000, 3000, 0.04, 0.4, {"lp": 5000}), L("tri", 700, 1050, 0.2, 0.4, {"t": 0.05})]},
	}
	# Los láseres y disparos modernos sustituyen a la versión clásica (más "arcade").
	base.merge(modern(), true)
	return base


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var all := sounds()
	var only := OS.get_cmdline_user_args()
	for name in all.keys():
		if not only.is_empty() and not only.has(name):
			continue
		var samples := render(all[name])
		save_wav(OUT_DIR + name + ".wav", samples)
	print("SFX generados: %d" % all.size())
	quit()


func render(spec: Dictionary) -> PackedFloat32Array:
	var total := 0.0
	for l in spec["layers"]:
		total = maxf(total, l["t"] + l["d"])
	var echo: Array = spec.get("echo", [0.0, 0.0, 0])
	total += echo[0] * echo[2] + 0.02 + (0.3 if spec.get("rev", 0.0) > 0.0 else 0.0)
	var n := int(total * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(spec))
	for l in spec["layers"]:
		_render_layer(buf, l, rng)
	var drive: float = spec.get("drive", 1.0)
	if drive > 1.0:
		for i in n:
			buf[i] = tanh(buf[i] * drive) / tanh(drive)
	if echo[2] > 0:
		var dly := int(echo[0] * SR)
		for r in echo[2]:
			for i in range(n - 1, dly - 1, -1):
				buf[i] += buf[i - dly] * echo[1]
	var rev: float = spec.get("rev", 0.0)
	if rev > 0.0:
		_reverb(buf, rev)
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var g := 0.89 / peak
	var fade := int(0.006 * SR)
	for i in n:
		var f := 1.0
		if i > n - fade:
			f = float(n - i) / fade
		buf[i] *= g * f
	return buf


func _render_layer(buf: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(l["t"] * SR)
	var len := int(l["d"] * SR)
	var phase := 0.0
	var lp_state := 0.0
	var hp_state := 0.0
	var hp_prev := 0.0
	var noise_val := 0.0
	var noise_phase := 0.0
	var f0: float = l["f0"]
	var f1: float = l["f1"]
	var vib: float = l.get("vib", 0.0)
	var vd: float = l.get("vd", 0.0)
	var a: float = l["a"]
	var k: float = l["k"]
	var lp: float = l.get("lp", 0.0)
	var hp: float = l.get("hp", 0.0)
	var ratio: float = l.get("ratio", 1.0)
	var index: float = l.get("index", 0.0)
	var ik: float = l.get("ik", 4.0)
	var mod_phase := 0.0
	for j in len:
		var i := start + j
		if i >= buf.size():
			break
		var u := float(j) / len
		var t := float(j) / SR
		var freq := f0 * pow(f1 / f0, u)
		if vib > 0.0:
			freq *= 1.0 + vd * sin(TAU * vib * t)
		phase = fposmod(phase + freq / SR, 1.0)
		var s := 0.0
		match l["w"]:
			"sine":
				s = sin(TAU * phase)
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = 2.0 * phase - 1.0
			"tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"fm":
				# FM de 2 operadores: timbre metálico/energético moderno; el índice decae con el tiempo.
				mod_phase = fposmod(mod_phase + freq * ratio / SR, 1.0)
				s = sin(TAU * phase + index * exp(-ik * u) * sin(TAU * mod_phase))
			"noise":
				# Ruido "con tono": se re-muestrea a la frecuencia indicada.
				noise_phase += freq / SR
				if noise_phase >= 1.0:
					noise_phase -= floorf(noise_phase)
					noise_val = rng.randf_range(-1.0, 1.0)
				s = noise_val
		if lp > 0.0:
			var alpha := clampf(TAU * lp / SR, 0.0, 1.0)
			lp_state += alpha * (s - lp_state)
			s = lp_state
		if hp > 0.0:
			var rc := 1.0 / (TAU * hp)
			var ah := rc / (rc + 1.0 / SR)
			hp_state = ah * (hp_state + s - hp_prev)
			hp_prev = s
			s = hp_state
		var env := 1.0
		if t < a:
			env = t / a
		else:
			env = exp(-k * (u - a / l["d"]))
			env *= clampf((1.0 - u) * 20.0, 0.0, 1.0)
		buf[i] += s * env * l["v"]


func save_wav(path: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	w.save_to_wav(ProjectSettings.globalize_path(path))


# --- Diseño "moderno" (inspirado en shooters MMO actuales, no en 8 bits) ---------------------
## Disparo láser por capas: transitorio de ruido (pegada) + cuerpo FM con barrido + brillo armónico
## + golpe grave + soplo de aire filtrado. Se completa con saturación suave y reverb corta.
func zap(f0: float, f1: float, d: float, ratio: float, index: float, o: Dictionary = {}) -> Array:
	var t: float = o.get("t", 0.0)
	var v: float = o.get("v", 1.0)
	var layers := [
		L("noise", 9000, 3500, 0.03, 0.5 * v, {"t": t, "hp": 2500, "k": 16.0, "a": 0.001}),
		L("fm", f0, f1, d, 0.75 * v, {"t": t, "ratio": ratio, "index": index, "ik": o.get("ik", 5.0), "k": o.get("k", 4.5), "lp": o.get("lp", 9000.0), "a": 0.002, "vib": o.get("vib", 0.0), "vd": o.get("vd", 0.0)}),
		L("sine", f0 * 2.0, f1 * 1.5, d * 0.5, 0.16 * v, {"t": t, "k": 6.0}),
		L("noise", 5200, 900, d * 0.9, o.get("air", 0.22) * v, {"t": t, "lp": 4500, "k": 4.0, "a": 0.004}),
	]
	if o.get("sub", 0.45) > 0.0:
		layers.append(L("sine", o.get("sub_f", 150.0), 42, minf(0.2, d), o.get("sub", 0.45) * v, {"t": t, "k": 7.0}))
	return layers


func modern() -> Dictionary:
	var m := {
		"laser_l01": {"layers": zap(1500, 220, 0.20, 1.5, 3.0)},
		"laser_l02": {"layers": zap(1750, 320, 0.14, 2.0, 2.5, {"v": 0.85}) + zap(1650, 300, 0.14, 2.0, 2.5, {"t": 0.055, "v": 0.85, "sub": 0.0})},
		"laser_l03": {"layers": zap(3300, 1500, 0.14, 3.0, 1.5, {"sub": 0.15, "air": 0.3})},
		"laser_l04": {"layers": zap(1150, 260, 0.15, 1.0, 4.0, {"k": 6.0})},
		"laser_l05": {"layers": zap(950, 180, 0.30, 0.5, 6.0, {"vib": 42.0, "vd": 0.06, "lp": 6000.0})},
		"laser_l06": {"layers": zap(720, 130, 0.30, 1.41, 5.0, {"lp": 5000.0}) + [L("noise", 2200, 700, 0.35, 0.3, {"lp": 2000, "vib": 30, "vd": 0.8, "k": 2.5})]},
		"laser_l07": {"layers": zap(2600, 2000, 0.26, 2.76, 2.0, {"vib": 9.0, "vd": 0.02, "k": 3.0, "sub": 0.2})},
		"laser_l08": {"layers": zap(1300, 200, 0.22, 1.0, 3.0) + [L("noise", 6000, 900, 0.18, 0.55, {"lp": 5000, "k": 6.0})]},
		"laser_l09": {"layers": zap(1800, 600, 0.32, 7.0, 8.0, {"lp": 7000.0}) + [L("noise", 4500, 2000, 0.3, 0.3, {"lp": 6000, "vib": 55, "vd": 0.9, "k": 3.0})]},
		"laser_l10": {"layers": zap(620, 60, 0.55, 0.5, 6.0, {"sub": 0.9, "sub_f": 120.0, "k": 2.8, "lp": 4000.0}), "drive": 1.6},
		"laser_l11": {"layers": zap(1200, 3000, 0.18, 1.5, 3.0, {"sub": 0.2})},
		"laser_l12": {"layers": zap(880, 700, 0.36, 2.0, 2.0, {"k": 2.2, "ik": 2.0})},
		"laser_l13": {"layers": zap(2100, 90, 0.65, 1.0, 7.0, {"sub": 0.8, "k": 2.2, "air": 0.35}), "drive": 1.5},
		"laser_l14": {"layers": zap(420, 300, 0.28, 0.25, 3.0, {"lp": 3000.0})},
		"laser_l15": {"layers": zap(320, 40, 0.6, 0.5, 8.0, {"sub": 0.9, "k": 2.0}) + [L("noise", 300, 3000, 0.55, 0.3, {"lp": 2500, "a": 0.25, "k": 1.2})]},
		"laser_l16": {"layers": zap(1600, 500, 0.15, 3.5, 3.0), "echo": [0.085, 0.45, 3]},
		"laser_l17": {"layers": zap(1400, 260, 0.2, 1.5, 3.0, {"v": 0.7}) + zap(1750, 330, 0.2, 1.5, 3.0, {"t": 0.03, "v": 0.6, "sub": 0.0}) + zap(2100, 400, 0.2, 1.5, 3.0, {"t": 0.06, "v": 0.5, "sub": 0.0})},
		"laser_l18": {"layers": zap(900, 50, 0.6, 0.7, 9.0, {"sub": 0.9, "k": 2.4}), "drive": 2.2},
		"laser_drone": {"layers": zap(2400, 1200, 0.09, 2.0, 1.5, {"sub": 0.0, "air": 0.12, "v": 0.7})},
		# Disparos alienígenas: más oscuros y graves que los del jugador para distinguirlos.
		"e_shot_light": {"layers": zap(780, 190, 0.17, 1.41, 3.0, {"v": 0.8, "sub": 0.3})},
		"e_shot_swarm": {"layers": zap(1500, 900, 0.09, 2.0, 2.0, {"v": 0.7, "sub": 0.0})},
		"e_shot_bio": {"layers": zap(420, 260, 0.2, 0.5, 4.0, {"vib": 18.0, "vd": 0.12, "lp": 3000.0, "v": 0.85})},
		"e_shot_crystal": {"layers": zap(3000, 2500, 0.13, 2.76, 2.0, {"sub": 0.1, "v": 0.75})},
		"e_shot_void": {"layers": zap(500, 110, 0.22, 0.5, 5.0, {"lp": 2500.0, "vib": 7.0, "vd": 0.05})},
		"e_heavy": {"layers": zap(420, 60, 0.36, 0.7, 6.0, {"sub": 0.8, "lp": 3000.0}), "drive": 1.5},
		"e_snipe_fire": {"layers": zap(2600, 300, 0.32, 3.0, 6.0, {"sub": 0.7, "air": 0.4}), "drive": 1.4},
	}
	# Reverb corta para todo lo moderno (sensación de espacio, no de chip de 8 bits).
	for k in m.keys():
		m[k]["rev"] = 0.22
	return m


## Reverb tipo Schroeder (4 peines + 2 pasa-todo), cola corta.
func _reverb(buf: PackedFloat32Array, wet: float) -> void:
	var n := buf.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [1116, 1188, 1277, 1356]:
		var delay: int = d * SR / 44100
		var line := PackedFloat32Array()
		line.resize(delay)
		var idx := 0
		for i in n:
			var y := line[idx]
			line[idx] = buf[i] + y * 0.72
			out[i] += y
			idx = (idx + 1) % delay
	for d in [556, 441]:
		var delay: int = d * SR / 44100
		var line := PackedFloat32Array()
		line.resize(delay)
		var idx := 0
		for i in n:
			var x := out[i]
			var y := line[idx]
			line[idx] = x + y * 0.5
			out[i] = y - x * 0.5
			idx = (idx + 1) % delay
	for i in n:
		buf[i] = buf[i] * (1.0 - wet * 0.4) + out[i] * wet * 0.22
