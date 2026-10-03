class_name ViewTest
extends Node2D
## Banco de pruebas de las vistas direccionales (--viewtest): cada nave con vistas completas
## dibujada en las 8 direcciones (columnas) con una flecha del rumbo real proyectado en isométrico,
## y en la última columna el sprite cenital antiguo para comparar el tamaño.

const RADIUS := 34.0
const CELL := Vector2(150, 118)
const HEADINGS := 8

var ids: Array = []


class Cell extends Node2D:
	var ship_id := ""
	var heading := 0.0
	var old := false

	func _draw() -> void:
		var tex := SpriteLib.get_tex("ships", ship_id)
		if old:
			SpriteLib.draw(self, tex, ViewTest.RADIUS, heading, 22.0)
		else:
			SpriteLib.draw_dir(self, "ships", ship_id, tex, ViewTest.RADIUS, heading, 22.0)
		# Rumbo real: flecha en el plano proyectada a pantalla, a la altura de la nave.
		var tip := Iso.to_screen(Vector2.from_angle(heading) * 62.0) + Vector2(0, -22)
		draw_line(Vector2(0, -22), tip, Color(1, 0.3, 0.3, 0.9), 2.0)
		draw_circle(tip, 4.0, Color(1, 0.3, 0.3))
		# Sombra / suelo de referencia
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.4, 0.8, 1, 0.25), 1.0)


func _ready() -> void:
	for id in GameData.SHIPS.keys():
		if SpriteLib.has_views("ships", id):
			ids.append(id)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-200, -200)
	add_child(bg)
	var font := ThemeDB.fallback_font
	for r in ids.size():
		var lbl := Label.new()
		lbl.text = GameData.SHIPS[ids[r]]["name"]
		lbl.position = Vector2(8, 40 + r * CELL.y)
		add_child(lbl)
		for c in HEADINGS + 1:
			var cell := Cell.new()
			cell.ship_id = ids[r]
			# Rumbos en el plano cuyo reflejo en pantalla cae en las 8 direcciones (e, se, s, sw, w, nw, n, ne).
			var screen_ang := (c % HEADINGS) * PI / 4.0
			cell.heading = Iso.to_plane(Vector2.from_angle(screen_ang)).angle()
			cell.old = c == HEADINGS
			cell.position = Vector2(200 + c * CELL.x, 70 + r * CELL.y)
			add_child(cell)
	for c in HEADINGS + 1:
		var h := Label.new()
		h.text = ["E", "SE", "S", "SO", "O", "NO", "N", "NE", "antiguo"][c]
		h.position = Vector2(185 + c * CELL.x, 4)
		add_child(h)
