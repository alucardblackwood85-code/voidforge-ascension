class_name Ground
extends Node2D
## Capa del plano: barrera exterior del sector, portal, minas, previsualización de colocación,
## arcos de energía y haces. Sin rejilla: el espacio se ve a través (fondo en Backdrop).

var sector: Sector
var mines: Array = []
var arcs: Array = []    # {a, b, color, t}
var beams: Array = []   # {a, b, color, t}
var t := 0.0
var edges: Array = []   # segmentos [a, b] del borde exterior del área navegable


func build() -> void:
	var ch := Sector.CHUNK
	for c in sector.cells.keys():
		var o := Vector2(c) * ch
		var sides := [[Vector2i(0, -1), o, o + Vector2(ch, 0)], [Vector2i(0, 1), o + Vector2(0, ch), o + Vector2(ch, ch)],
			[Vector2i(-1, 0), o, o + Vector2(0, ch)], [Vector2i(1, 0), o + Vector2(ch, 0), o + Vector2(ch, ch)]]
		for s in sides:
			if not sector.cells.has(c + s[0]):
				edges.append([s[1], s[2]])


func add_arc(a: Vector2, b: Vector2, color: Color) -> void:
	arcs.append({"a": a, "b": b, "color": color, "t": 0.25})


func add_beam(a: Vector2, b: Vector2, color: Color) -> void:
	beams.append({"a": a, "b": b, "color": color, "t": 0.35})


func _process(delta: float) -> void:
	t += delta
	for list in [arcs, beams]:
		for a in list.duplicate():
			a["t"] -= delta
			if a["t"] <= 0.0:
				list.erase(a)
	queue_redraw()


func _draw() -> void:
	var b: Dictionary = sector.biome
	var border: Color = b.get("border", Color(1, 0.5, 0.3))
	var player_pos := sector.player.plane_pos if sector.player else Vector2.ZERO
	draw_set_transform_matrix(Iso.MATRIX)
	# Barrera de energía: sólo visible cerca de la nave, con pulso suave (no son "cuadrantes").
	for e in edges:
		var a: Vector2 = e[0]
		var c: Vector2 = e[1]
		var mid := (a + c) * 0.5
		var near := clampf(1.0 - (Geometry2D.get_closest_point_to_segment(player_pos, a, c).distance_to(player_pos) - 300.0) / 1400.0, 0.0, 1.0)
		if near <= 0.0 and mid.distance_to(player_pos) > 3000.0:
			continue
		var pulse := 0.5 + 0.5 * sin(t * 2.0 + mid.x * 0.002)
		draw_line(a, c, Color(border, 0.05 + 0.10 * near), 40.0)
		draw_line(a, c, Color(border, 0.10 + 0.35 * near * pulse), 6.0)
	# Portal de extracción
	var g := sector.gate_pos
	var gp := 0.5 + 0.5 * sin(t * 3.0)
	var gc := UiTheme.GOOD if sector.objective_done else UiTheme.ACCENT
	draw_circle(g, 150.0, Color(gc, 0.06 + 0.05 * gp))
	draw_arc(g, 150.0, 0, TAU, 64, Color(gc, 0.7), 4.0)
	draw_arc(g, 110.0, t, t + PI * 1.2, 32, Color(gc, 0.5), 3.0)
	draw_arc(g, 110.0, t + PI, t + PI * 2.2, 32, Color(gc, 0.5), 3.0)
	for m in mines:
		var armed: bool = m["arm"] <= 0.0
		draw_circle(m["pos"], 14.0, Color(1, 0.3, 0.3, 0.9 if armed and int(t * 4) % 2 == 0 else 0.5))
		draw_arc(m["pos"], 90.0, 0, TAU, 32, Color(1, 0.3, 0.3, 0.2), 2.0)
	# Previsualización de colocación (4.3)
	if sector.placing != "":
		var mp := sector.mouse_plane()
		var ok := not sector.is_blocked(mp) and mp.distance_to(player_pos) <= 500.0
		draw_circle(mp, 90.0, Color(0.3, 1, 0.4, 0.15) if ok else Color(1, 0.2, 0.2, 0.15))
		draw_arc(mp, 90.0, 0, TAU, 32, Color(0.3, 1, 0.4, 0.7) if ok else Color(1, 0.2, 0.2, 0.7), 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for a in arcs:
		var pa := Iso.to_screen(a["a"]) + Vector2(0, -16)
		var pb := Iso.to_screen(a["b"]) + Vector2(0, -16)
		var mid := (pa + pb) * 0.5 + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		draw_polyline(PackedVector2Array([pa, mid, pb]), Color(a["color"], a["t"] * 4.0), 2.0)
	for bm in beams:
		var pa := Iso.to_screen(bm["a"]) + Vector2(0, -20)
		var pb := Iso.to_screen(bm["b"]) + Vector2(0, -20)
		var k: float = bm["t"] / 0.35
		draw_line(pa, pb, Color(bm["color"], 0.35 * k), 14.0 * k)
		draw_line(pa, pb, Color(1, 1, 1, 0.9 * k), 3.0)
