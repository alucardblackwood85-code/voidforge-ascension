class_name Shapes
## Siluetas procedurales (placeholder hasta tener sprites). +X = frente de la nave. Radio ~1.

const PLAYER := {
	"caza": [Vector2(1.2, 0), Vector2(0.1, 0.35), Vector2(-0.4, 0.95), Vector2(-0.7, 0.9), Vector2(-0.45, 0.25), Vector2(-0.8, 0), Vector2(-0.45, -0.25), Vector2(-0.7, -0.9), Vector2(-0.4, -0.95), Vector2(0.1, -0.35)],
	"tanque": [Vector2(1.0, 0.25), Vector2(1.0, -0.25), Vector2(0.4, -0.85), Vector2(-0.8, -0.85), Vector2(-1.0, -0.4), Vector2(-1.0, 0.4), Vector2(-0.8, 0.85), Vector2(0.4, 0.85)],
	"carguera": [Vector2(1.0, 0), Vector2(0.6, 0.5), Vector2(-0.9, 0.7), Vector2(-1.0, 0.3), Vector2(-1.0, -0.3), Vector2(-0.9, -0.7), Vector2(0.6, -0.5)],
	"crucero": [Vector2(1.3, 0), Vector2(0.5, 0.3), Vector2(0.1, 0.8), Vector2(-0.8, 0.7), Vector2(-0.6, 0.2), Vector2(-1.0, 0), Vector2(-0.6, -0.2), Vector2(-0.8, -0.7), Vector2(0.1, -0.8), Vector2(0.5, -0.3)],
	"batalla": [Vector2(1.4, 0), Vector2(0.8, 0.35), Vector2(0.3, 0.45), Vector2(0.0, 1.0), Vector2(-0.9, 0.9), Vector2(-0.7, 0.35), Vector2(-1.1, 0.2), Vector2(-1.1, -0.2), Vector2(-0.7, -0.35), Vector2(-0.9, -0.9), Vector2(0.0, -1.0), Vector2(0.3, -0.45), Vector2(0.8, -0.35)],
}

const ENEMY := {
	"insect": [Vector2(1.0, 0), Vector2(0.3, 0.3), Vector2(0.2, 0.9), Vector2(-0.1, 0.4), Vector2(-0.4, 0.95), Vector2(-0.5, 0.3), Vector2(-0.9, 0.6), Vector2(-0.8, 0), Vector2(-0.9, -0.6), Vector2(-0.5, -0.3), Vector2(-0.4, -0.95), Vector2(-0.1, -0.4), Vector2(0.2, -0.9), Vector2(0.3, -0.3)],
	"scrap": [Vector2(0.9, 0.2), Vector2(0.5, 0.7), Vector2(-0.2, 0.8), Vector2(-0.8, 0.4), Vector2(-0.6, -0.1), Vector2(-0.9, -0.6), Vector2(-0.1, -0.9), Vector2(0.6, -0.5), Vector2(1.0, -0.2)],
	"oval": [Vector2(1.0, 0), Vector2(0.7, 0.6), Vector2(0.0, 0.85), Vector2(-0.7, 0.65), Vector2(-1.0, 0), Vector2(-0.7, -0.65), Vector2(0.0, -0.85), Vector2(0.7, -0.6)],
	"needle": [Vector2(1.4, 0), Vector2(0.0, 0.2), Vector2(-0.5, 0.9), Vector2(-0.8, 0.8), Vector2(-0.6, 0.15), Vector2(-1.0, 0), Vector2(-0.6, -0.15), Vector2(-0.8, -0.8), Vector2(-0.5, -0.9), Vector2(0.0, -0.2)],
	"drill": [Vector2(1.4, 0), Vector2(0.5, 0.45), Vector2(0.2, 0.9), Vector2(-0.8, 0.7), Vector2(-1.0, 0), Vector2(-0.8, -0.7), Vector2(0.2, -0.9), Vector2(0.5, -0.45)],
	"hex": [Vector2(1.0, 0), Vector2(0.5, 0.87), Vector2(-0.5, 0.87), Vector2(-1.0, 0), Vector2(-0.5, -0.87), Vector2(0.5, -0.87)],
	"claw": [Vector2(1.0, 0), Vector2(0.4, 0.4), Vector2(0.0, 1.0), Vector2(-0.4, 0.4), Vector2(-1.0, 0), Vector2(-0.4, -0.4), Vector2(0.0, -1.0), Vector2(0.4, -0.4)],
	"skull": [Vector2(1.0, 0.3), Vector2(1.0, -0.3), Vector2(0.6, -0.7), Vector2(-0.3, -0.9), Vector2(-1.0, -0.5), Vector2(-0.8, 0), Vector2(-1.0, 0.5), Vector2(-0.3, 0.9), Vector2(0.6, 0.7)],
	"tri": [Vector2(1.2, 0), Vector2(-0.8, 0.95), Vector2(-0.5, 0), Vector2(-0.8, -0.95)],
	"mother": [Vector2(1.0, 0.3), Vector2(1.0, -0.3), Vector2(0.6, -0.8), Vector2(-0.6, -0.9), Vector2(-1.0, -0.5), Vector2(-1.0, 0.5), Vector2(-0.6, 0.9), Vector2(0.6, 0.8)],
	"nest": [Vector2(1.0, 0), Vector2(0.62, 0.78), Vector2(-0.22, 0.97), Vector2(-0.9, 0.43), Vector2(-0.9, -0.43), Vector2(-0.22, -0.97), Vector2(0.62, -0.78)],
}


static func scaled(points: Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * s)
	return out


## Dibuja un casco con relleno, borde y acento en `ci` (CanvasItem) usando la matriz iso.
static func draw_hull(ci: CanvasItem, points: Array, size: float, angle: float, h: float, fill: Color, edge: Color, accent: Color) -> void:
	ci.draw_set_transform_matrix(Iso.shape_matrix(angle, h, size))
	var poly := scaled(points, 1.0)
	ci.draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, edge, 1.5 / size, true)
	ci.draw_circle(Vector2(0.2, 0), 0.18, accent)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
