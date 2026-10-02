class_name Ground
extends Node2D
## Plano del sector: suelo de chunks, rejilla, portal de extracción, minas y arcos de energía.

var sector: Sector
var mines: Array = []
var arcs: Array = []   # {a, b, color, t}
var t := 0.0
var blobs: Array = []


func build() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = sector.rng.seed + 7
	for c in sector.cells.keys():
		for i in 2:
			blobs.append({"p": sector.cell_center(c) + Vector2(r.randf_range(-500, 500), r.randf_range(-500, 500)), "r": r.randf_range(250, 520)})


func add_arc(a: Vector2, b: Vector2, color: Color) -> void:
	arcs.append({"a": a, "b": b, "color": color, "t": 0.25})


func _process(delta: float) -> void:
	t += delta
	for a in arcs.duplicate():
		a["t"] -= delta
		if a["t"] <= 0.0:
			arcs.erase(a)
	queue_redraw()


func _draw() -> void:
	var b: Dictionary = sector.biome
	var ch := Sector.CHUNK
	draw_set_transform_matrix(Iso.MATRIX)
	for c in sector.cells.keys():
		var rect := Rect2(Vector2(c) * ch, Vector2.ONE * ch)
		var visited: bool = sector.cells[c]["visited"]
		draw_rect(rect, Color(0.08, 0.09, 0.13, 0.55 if visited else 0.35))
		var step := 200.0
		var x := rect.position.x
		while x <= rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), b["grid"], 2.0)
			x += step
		var y := rect.position.y
		while y <= rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), b["grid"], 2.0)
			y += step
	for bl in blobs:
		draw_circle(bl["p"], bl["r"], b["nebula"])
		draw_circle(bl["p"], bl["r"] * 0.6, b["nebula"])
	# Bordes del área navegable
	for c in sector.cells.keys():
		var o := Vector2(c) * ch
		var edges := [[Vector2i(0, -1), o, o + Vector2(ch, 0)], [Vector2i(0, 1), o + Vector2(0, ch), o + Vector2(ch, ch)],
			[Vector2i(-1, 0), o, o + Vector2(0, ch)], [Vector2i(1, 0), o + Vector2(ch, 0), o + Vector2(ch, ch)]]
		for e in edges:
			if not sector.cells.has(c + e[0]):
				draw_line(e[1], e[2], Color(1.0, 0.35, 0.2, 0.35), 6.0)
	# Portal de extracción
	var g := sector.gate_pos
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var gc := UiTheme.GOOD if sector.objective_done else UiTheme.ACCENT
	draw_circle(g, 150.0, Color(gc, 0.06 + 0.05 * pulse))
	draw_arc(g, 150.0, 0, TAU, 64, Color(gc, 0.7), 4.0)
	draw_arc(g, 110.0, t, t + PI * 1.2, 32, Color(gc, 0.5), 3.0)
	draw_arc(g, 110.0, t + PI, t + PI * 2.2, 32, Color(gc, 0.5), 3.0)
	for m in mines:
		var armed: bool = m["arm"] <= 0.0
		draw_circle(m["pos"], 14.0, Color(1, 0.3, 0.3, 0.9 if armed and int(t * 4) % 2 == 0 else 0.5))
		draw_arc(m["pos"], 90.0, 0, TAU, 32, Color(1, 0.3, 0.3, 0.2), 2.0)
	# Previsualización de colocación
	if sector.placing != "":
		var mp := sector.mouse_plane()
		var ok := not sector.is_blocked(mp) and mp.distance_to(sector.player.plane_pos) <= 500.0
		draw_circle(mp, 90.0, Color(0.3, 1, 0.4, 0.15) if ok else Color(1, 0.2, 0.2, 0.15))
		draw_arc(mp, 90.0, 0, TAU, 32, Color(0.3, 1, 0.4, 0.7) if ok else Color(1, 0.2, 0.2, 0.7), 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for a in arcs:
		var pa := Iso.to_screen(a["a"]) + Vector2(0, -16)
		var pb := Iso.to_screen(a["b"]) + Vector2(0, -16)
		var mid := (pa + pb) * 0.5 + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		draw_polyline(PackedVector2Array([pa, mid, pb]), Color(a["color"], a["t"] * 4.0), 2.0)
