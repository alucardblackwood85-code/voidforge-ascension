class_name Fx
extends Node2D
## Efectos visuales efímeros: anillos, chispas, explosiones, números de daño y avisos de área.

var kind := "ring"
var plane_pos := Vector2.ZERO
var life := 0.5
var max_life := 0.5
var r := 40.0
var color := Color.WHITE
var text := ""
var sparks: Array = []
# Telegraph de área
var sector: Sector
var dmg := 0.0


func _ready() -> void:
	position = Iso.to_screen(plane_pos)
	if kind == "explosion" or kind == "spark":
		var n := 14 if kind == "explosion" else 5
		for i in n:
			sparks.append({"d": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0), "s": randf_range(2.0, 4.0)})


func _process(delta: float) -> void:
	life -= delta
	if kind == "number":
		position.y -= 40.0 * delta
	if life <= 0.0:
		if kind == "telegraph":
			sector.explode(plane_pos, r, dmg, color, null)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - life / max_life
	match kind:
		"ring":
			draw_set_transform_matrix(Iso.MATRIX)
			draw_arc(Vector2.ZERO, r * (0.4 + t), 0, TAU, 40, Color(color, 1.0 - t), 3.0 / Iso.K)
		"spark":
			for s in sparks:
				var p: Vector2 = Iso.to_screen(s["d"] * 30.0 * t) + Vector2(0, -16)
				draw_circle(p, s["s"] * (1.0 - t), Color(color.lightened(0.4), 1.0 - t))
		"explosion":
			draw_set_transform_matrix(Iso.MATRIX)
			draw_circle(Vector2.ZERO, r * (0.3 + 0.9 * t), Color(color, 0.5 * (1.0 - t)))
			draw_arc(Vector2.ZERO, r * (0.5 + t), 0, TAU, 40, Color(1, 0.9, 0.6, 1.0 - t), 4.0 / Iso.K)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			for s in sparks:
				var p: Vector2 = Iso.to_screen(s["d"] * r * 1.4 * t) + Vector2(0, -20.0 * (1.0 - t))
				draw_circle(p, s["s"] * 1.5 * (1.0 - t), Color(1, 0.7, 0.3, 1.0 - t))
		"number":
			var f := ThemeDB.fallback_font
			var sz := 18 if color == Color("ffe04a") else 14
			draw_string_outline(f, Vector2(-30, -30), text, HORIZONTAL_ALIGNMENT_CENTER, 60, sz, 4, Color(0, 0, 0, 0.8 * (1.0 - t)))
			draw_string(f, Vector2(-30, -30), text, HORIZONTAL_ALIGNMENT_CENTER, 60, sz, Color(color, 1.0 - t * t))
		"telegraph":
			draw_set_transform_matrix(Iso.MATRIX)
			draw_circle(Vector2.ZERO, r, Color(color, 0.08 + 0.12 * t))
			draw_circle(Vector2.ZERO, r * t, Color(color, 0.25))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 0.8), 2.0 / Iso.K)
