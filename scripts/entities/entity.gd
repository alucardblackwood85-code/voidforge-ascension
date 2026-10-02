class_name Entity
extends Node2D
## Base de todo objeto del sector: posición lógica en el plano, radio de colisión y proyección iso.

var sector: Sector
var plane_pos := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 20.0
var height := 18.0          # elevación visual sobre el plano (px)
var alive := true


## Impacto del jugador. Lo sobrescriben enemigos y nodos de recursos.
func take_hit(_amount: float, _info: Dictionary) -> void:
	pass


func sync_screen() -> void:
	position = Iso.to_screen(plane_pos)


func draw_shadow(r: float, alpha: float = 0.35) -> void:
	draw_set_transform_matrix(Iso.MATRIX)
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_ring(r: float, color: Color, width: float = 2.0, h: float = 0.0) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(0, -h)) * Iso.MATRIX)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, color, width / Iso.K, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_bar(y: float, w: float, frac: float, color: Color, bg: Color = Color(0, 0, 0, 0.6)) -> void:
	var r := Rect2(-w * 0.5, y, w, 4)
	draw_rect(r, bg)
	draw_rect(Rect2(r.position, Vector2(w * clampf(frac, 0.0, 1.0), 4)), color)
