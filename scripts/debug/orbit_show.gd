class_name OrbitShow
extends Node2D
## Demostración del movimiento (--orbit): cada nave con vistas 3D orbita 10 s alrededor de un
## alien, apuntándole siempre y disparándole. A mitad de vuelta invierte el sentido para mostrar
## la oscilación hacia ambos lados. Al terminar la lista vuelve a empezar.

const SHIP_TIME := 10.0
const ORBIT_R := 230.0
const RADIUS := 34.0
const TARGET_ID := "xenomita"

var ids: Array = []
var idx := 0
var t := 0.0
var orbit_ang := 0.0
var ship: ShipView
var target_pos := Vector2.ZERO
var label: Label
var camera: Camera2D
var beams: Array = []   # [{from, life}]


class ShipView extends Node2D:
	var ship_id := ""
	var plane_pos := Vector2.ZERO
	var heading := 0.0
	var velocity := Vector2.ZERO
	var max_speed := 1.0

	func _draw() -> void:
		var tex := SpriteLib.get_tex("ships", ship_id)
		SpriteLib.draw_dir(self, "ships", ship_id, tex, OrbitShow.RADIUS, heading, 22.0, Color.WHITE, SpriteLib.strafe_of(heading, velocity, max_speed))


class TargetView extends Node2D:
	var anim := 0.0

	func _process(delta: float) -> void:
		anim += delta
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2(0, -16), 58.0, 0, TAU, 48, Color(1, 0.3, 0.3, 0.8), 2.0)
		SpriteLib.draw(self, SpriteLib.get_tex("enemies", OrbitShow.TARGET_ID), 40.0, anim * 0.4, 16.0)


func _ready() -> void:
	for id in GameData.SHIPS.keys():
		if SpriteLib.has_views("ships", id):
			ids.append(id)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/ferron.png") if ResourceLoader.exists("res://assets/backgrounds/ferron.png") else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(2400, 1500)
	bg.position = Vector2(-1200, -750)
	bg.modulate = Color(0.6, 0.6, 0.7)
	add_child(bg)
	var tv := TargetView.new()
	tv.position = Iso.to_screen(target_pos)
	add_child(tv)
	ship = ShipView.new()
	add_child(ship)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * 1.5
	camera.position = Vector2(0, -20)
	add_child(camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	ui.add_child(label)
	_next_ship(0)


func _next_ship(i: int) -> void:
	idx = i % ids.size()
	t = 0.0
	ship.ship_id = ids[idx]
	ship.max_speed = float(GameData.SHIPS[ids[idx]]["speed"]) * GameData.SPEED_UNIT
	for m in ["_va", "_vt", "_vbank"]:
		if ship.has_meta(m):
			ship.remove_meta(m)
	label.text = "%s  (%d/%d) — orbitando el objetivo" % [GameData.SHIPS[ids[idx]]["name"], idx + 1, ids.size()]


func _process(delta: float) -> void:
	t += delta
	if t >= SHIP_TIME:
		_next_ship(idx + 1)
	# Velocidad angular: sentido horario la primera mitad, antihorario la segunda (con transición).
	var speed := ship.max_speed / ORBIT_R
	var dir := 1.0 if t < SHIP_TIME * 0.5 else -1.0
	var ramp := clampf(absf(t - SHIP_TIME * 0.5) / 0.8, 0.0, 1.0)
	var prev := ship.plane_pos
	orbit_ang += speed * dir * ramp * delta
	ship.plane_pos = target_pos + Vector2.from_angle(orbit_ang) * ORBIT_R
	ship.velocity = (ship.plane_pos - prev) / maxf(delta, 0.001)
	ship.heading = (target_pos - ship.plane_pos).angle()
	ship.position = Iso.to_screen(ship.plane_pos)
	ship.queue_redraw()
	# Disparo de láser cada 1,2 s (como la andanada del juego).
	if fmod(t, 1.2) < delta:
		beams.append({"from": ship.position + Vector2(0, -22), "life": 0.18})
	for b in beams:
		b["life"] -= delta
	beams = beams.filter(func(b): return b["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var to := Iso.to_screen(target_pos) + Vector2(0, -16)
	for b in beams:
		var a: float = clampf(b["life"] / 0.18, 0.0, 1.0)
		draw_line(b["from"], to, Color(1, 0.25, 0.25, a), 4.0)
		draw_line(b["from"], to, Color(1, 0.85, 0.85, a), 1.5)
