class_name Iso
## Proyección isométrica 2D. La lógica vive en el "plano" (top-down) y se dibuja en pantalla.
## Plano -> pantalla: x' = k (x - y), y' = k (x + y) / 2.

const K := 0.7071
static var MATRIX := Transform2D(Vector2(K, K * 0.5), Vector2(-K, K * 0.5), Vector2.ZERO)


static func to_screen(p: Vector2) -> Vector2:
	return Vector2(K * (p.x - p.y), K * 0.5 * (p.x + p.y))


static func to_plane(s: Vector2) -> Vector2:
	var a := s.x / K
	var b := 2.0 * s.y / K
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Matriz para dibujar una forma local (rotada `angle` en el plano) elevada `height` píxeles.
static func shape_matrix(angle: float, height: float = 0.0, scale: float = 1.0) -> Transform2D:
	return Transform2D(0.0, Vector2(0.0, -height)) * MATRIX * Transform2D(angle, Vector2.ONE * scale, 0.0, Vector2.ZERO)


## Matriz para sprites prerenderizados: aplasta menos en vertical (0.65 en vez de 0.5) para
## conservar sensación de volumen, y aplica un factor de tamaño visual independiente del radio físico.
static func sprite_matrix(angle: float, height: float, scale: float) -> Transform2D:
	var m := Transform2D(Vector2(K, K * 0.65), Vector2(-K, K * 0.65), Vector2.ZERO)
	return Transform2D(0.0, Vector2(0.0, -height)) * m * Transform2D(angle, Vector2.ONE * scale, 0.0, Vector2.ZERO)
