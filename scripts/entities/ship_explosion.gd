class_name ShipExplosion
extends Node2D
## Explosión universal de nave (jugador y alienígenas): destello, bolas de fuego escalonadas, humo,
## metralla, chispas y onda expansiva. Escala con el tamaño de la nave. Texturas en assets/fx/.

const LIFE := 1.8

static var _fire: Texture2D
static var _smoke: Texture2D
static var _debris: Texture2D

var plane_pos := Vector2.ZERO
var size := 60.0
var t := 0.0
var parts: Array = []


static func _tex(name: String) -> Texture2D:
	var path := "res://assets/fx/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	if _fire == null:
		_fire = _tex("explosion_fireball")
		_smoke = _tex("explosion_smoke")
		_debris = _tex("debris")
	position = Iso.to_screen(plane_pos)
	var n_fire := 3 + int(size / 40.0)
	for i in n_fire:
		parts.append({"k": "fire", "delay": randf() * 0.25, "off": Vector2.from_angle(randf() * TAU) * randf() * size * 0.5,
			"rot": randf() * TAU, "spin": randf_range(-1.5, 1.5), "s": randf_range(0.7, 1.2), "life": randf_range(0.55, 0.8)})
	for i in 6:
		parts.append({"k": "smoke", "delay": 0.1 + randf() * 0.3, "off": Vector2.from_angle(randf() * TAU) * randf() * size * 0.4,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(10, 35), "rot": randf() * TAU, "spin": randf_range(-0.6, 0.6), "s": randf_range(0.9, 1.5), "life": randf_range(1.1, 1.6)})
	for i in 18:
		parts.append({"k": "spark", "delay": 0.0, "off": Vector2.ZERO, "vel": Vector2.from_angle(randf() * TAU) * randf_range(120, 360) * size / 60.0,
			"s": randf_range(1.5, 3.5), "life": randf_range(0.4, 0.9)})


func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var lift := Vector2(0, -18)
	# Onda expansiva sobre el plano.
	var wave_t := clampf(t / 0.6, 0.0, 1.0)
	if wave_t < 1.0:
		draw_set_transform_matrix(Iso.MATRIX)
		draw_arc(Vector2.ZERO, size * (0.4 + 2.2 * wave_t), 0, TAU, 48, Color(1, 0.85, 0.6, 0.6 * (1.0 - wave_t)), 6.0 / Iso.K)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# Humo (debajo del fuego).
	for p in parts:
		if p["k"] != "smoke":
			continue
		var lt: float = (t - p["delay"]) / p["life"]
		if lt <= 0.0 or lt >= 1.0:
			continue
		var pos: Vector2 = lift + Iso.to_screen(p["off"] + p["vel"] * (t - p["delay"]))
		var s: float = size * p["s"] * (0.6 + lt)
		var a: float = (1.0 - lt) * 0.7
		_tex_draw(_smoke, pos, s, p["rot"] + p["spin"] * t, Color(0.6, 0.55, 0.5, a), Color(0.15, 0.13, 0.12, a))
	# Bolas de fuego escalonadas.
	for p in parts:
		if p["k"] != "fire":
			continue
		var lt: float = (t - p["delay"]) / p["life"]
		if lt <= 0.0 or lt >= 1.0:
			continue
		var s: float = size * p["s"] * (0.35 + 0.9 * sqrt(lt))
		var a := 1.0 - lt * lt
		_tex_draw(_fire, lift + Iso.to_screen(p["off"]), s, p["rot"] + p["spin"] * t, Color(1, 1, 1, a), Color(1.0, 0.6, 0.2, a))
	# Metralla.
	if _debris and t < 0.7:
		var dt := t / 0.7
		_tex_draw(_debris, lift, size * (0.6 + 1.6 * dt), 0.0, Color(1, 1, 1, 1.0 - dt), Color.WHITE)
	for p in parts:
		if p["k"] != "spark":
			continue
		var lt: float = t / p["life"]
		if lt >= 1.0:
			continue
		var pos: Vector2 = lift + Iso.to_screen(p["vel"] * t * (1.0 - lt * 0.4))
		draw_circle(pos, p["s"] * (1.0 - lt), Color(1, 0.8, 0.4, 1.0 - lt))
	# Destello inicial.
	if t < 0.18:
		draw_circle(lift, size * 1.3, Color(1, 1, 0.9, 0.7 * (1.0 - t / 0.18)))


func _tex_draw(tex: Texture2D, pos: Vector2, s: float, rot: float, mod: Color, fallback: Color) -> void:
	if tex:
		draw_set_transform(pos, rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false, mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_circle(pos, s * 0.4, fallback)
