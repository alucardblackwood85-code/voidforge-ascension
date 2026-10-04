class_name ShipSpin
extends Control
## Visor del hangar: la nave gira en vista semifrontal sobre una plataforma holográfica, como en los MMO
## de naves. Usa la hoja assets/sprites/hangar/<id>.webp (36 fotogramas, 6x6, generada con
## tools/build_hangar_views.ps1); funde fotogramas contiguos para que el giro sea suave y se puede
## arrastrar con el ratón para girarla a mano. Sin hoja, muestra el sprite plano con balanceo.

const COLS := 6
const FRAMES := 36
const AUTO_SPEED := 22.0      # grados por segundo

var ship_id := ""
var sheet: Texture2D
var flat: Texture2D
var angle := 200.0            # empieza de tres cuartos, con la proa hacia el espectador
var t := 0.0
var dragging := false
var idle := 0.0
var show_floor := true
var zoom := 1.0


static func has_sheet(id: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/hangar/%s.webp" % id)


static func make(id: String, size: Vector2, p_zoom: float = 1.0) -> ShipSpin:
	var s := ShipSpin.new()
	s.ship_id = id
	s.custom_minimum_size = size
	s.zoom = p_zoom
	if has_sheet(id):
		s.sheet = load("res://assets/sprites/hangar/%s.webp" % id)
	else:
		s.flat = W.icon("ship", id)
	return s


## Un fotograma suelto de la hoja (para iconos en tres cuartos).
static func frame_tex(id: String, frame: int) -> Texture2D:
	if not has_sheet(id):
		return W.icon("ship", id)
	var sh: Texture2D = load("res://assets/sprites/hangar/%s.webp" % id)
	var fs := sh.get_width() / COLS
	var a := AtlasTexture.new()
	a.atlas = sh
	a.region = Rect2((frame % COLS) * fs, (frame / COLS) * fs, fs, fs)
	return a


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		idle = 0.0
	elif event is InputEventMouseMotion and dragging:
		angle -= event.relative.x * 0.6
		idle = 0.0


func _process(delta: float) -> void:
	t += delta
	idle += delta
	if not dragging and idle > 1.5:
		angle += AUTO_SPEED * delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y * 1.6) * 0.42
	if show_floor:
		# Plataforma: elipse con anillos que laten y un haz de luz hacia arriba.
		var fc := c + Vector2(0, r * 0.42)
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, r, Color(0.2, 0.9, 1.0, 0.07))
		for i in 3:
			var rr := r * (0.55 + 0.22 * i) + 3.0 * sin(t * 2.0 + i)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 72, Color(0.3, 0.9, 1.0, 0.32 - i * 0.08), 2.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var beam := PackedVector2Array([fc + Vector2(-r * 0.7, 0), fc + Vector2(r * 0.7, 0), fc + Vector2(r * 0.45, -r * 1.1), fc + Vector2(-r * 0.45, -r * 1.1)])
		draw_colored_polygon(beam, Color(0.3, 0.9, 1.0, 0.035))
	var bob := sin(t * 1.4) * 3.0
	if sheet:
		var fs := float(sheet.get_width()) / COLS
		var pos: float = fposmod(angle, 360.0) / (360.0 / FRAMES)
		var i0 := int(floor(pos)) % FRAMES
		var i1 := (i0 + 1) % FRAMES
		var f: float = pos - floor(pos)
		var side := minf(size.x, size.y * 1.7) * 1.05 * zoom
		var dst := Rect2(c - Vector2(side, side) * 0.5 + Vector2(0, bob - side * 0.06), Vector2(side, side))
		draw_texture_rect_region(sheet, dst, Rect2((i0 % COLS) * fs, (i0 / COLS) * fs, fs, fs), Color(1, 1, 1, 1.0))
		draw_texture_rect_region(sheet, dst, Rect2((i1 % COLS) * fs, (i1 / COLS) * fs, fs, fs), Color(1, 1, 1, f))
	elif flat:
		var s := r * 1.5
		draw_set_transform(c + Vector2(0, bob - r * 0.1), -PI * 0.5 + sin(t * 0.6) * 0.4, Vector2.ONE)
		draw_texture_rect(flat, Rect2(-s * 0.5, -s * 0.5, s, s), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
