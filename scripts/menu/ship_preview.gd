class_name ShipPreview
extends Control
## Vista previa animada de una nave: gira lentamente sobre una plataforma holográfica.

var tex: Texture2D
var t := 0.0
var spin := true


static func make(p_tex: Texture2D, size: Vector2) -> ShipPreview:
	var p := ShipPreview.new()
	p.tex = p_tex
	p.custom_minimum_size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	# Plataforma holográfica (elipse isométrica) con anillos animados.
	draw_set_transform(c + Vector2(0, r * 0.35), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color(0.2, 0.9, 1.0, 0.06))
	for i in 3:
		var rr := r * (0.6 + 0.2 * i) + 4.0 * sin(t * 2.0 + i)
		draw_arc(Vector2.ZERO, rr, 0, TAU, 64, Color(0.3, 0.9, 1.0, 0.25 - i * 0.06), 2.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if tex == null:
		return
	var ang := -PI * 0.5 + (sin(t * 0.6) * 0.5 if spin else 0.0)   # proa hacia arriba, con balanceo
	var bob := sin(t * 1.5) * 4.0
	var s := r * 1.6
	draw_set_transform(c + Vector2(0, bob - r * 0.05), ang, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
