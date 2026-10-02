class_name RankBadge
extends Control
## Insignia de rango dibujada por código (coherente para los 21 rangos):
## 1-9 tropa/suboficiales: galones (chevrons) y arcos; 10-17 oficiales: barras y rombos; 18-21 generales: estrellas.

var level := 1


static func make(p_level: int, size: float = 64.0) -> RankBadge:
	var b := RankBadge.new()
	b.level = p_level
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = "%s (nivel %d)" % [GameState.rank_name(p_level), p_level]
	return b


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var gold := Color("ffd84a")
	var silver := Color("d8e0f0")
	var bronze := Color("d08a4a")
	# Escudo de fondo
	var shield := PackedVector2Array([c + Vector2(-0.42, -0.45) * s, c + Vector2(0.42, -0.45) * s, c + Vector2(0.42, 0.1) * s, c + Vector2(0, 0.48) * s, c + Vector2(-0.42, 0.1) * s])
	var tier_col := bronze if level <= 9 else (silver if level <= 17 else gold)
	draw_colored_polygon(shield, Color(0.06, 0.08, 0.14))
	var closed := shield.duplicate()
	closed.append(shield[0])
	draw_polyline(closed, tier_col, maxf(2.0, s * 0.04), true)
	if level <= 9:
		# Galones: 1-3 chevrons, + arcos (rockers) a partir del 4.
		var chevrons := (level - 1) % 3 + 1 if level > 1 else 0
		var rockers := (level - 1) / 3
		for i in chevrons:
			var y := -0.18 + i * 0.13
			draw_polyline(PackedVector2Array([c + Vector2(-0.26, y + 0.08) * s, c + Vector2(0, y - 0.04) * s, c + Vector2(0.26, y + 0.08) * s]), bronze.lightened(0.3), s * 0.06, true)
		for i in rockers:
			var y := 0.2 + i * 0.1
			draw_arc(c + Vector2(0, y - 0.25) * s, s * 0.28, 0.35, PI - 0.35, 12, bronze.lightened(0.15), s * 0.05, true)
		if level == 1:
			draw_circle(c, s * 0.08, bronze)
	elif level <= 17:
		# Oficiales: 1-4 barras (10-13) o 1-4 rombos (14-17).
		var n := (level - 10) % 4 + 1
		var diamonds := level >= 14
		for i in n:
			var x := (float(i) - (n - 1) * 0.5) * 0.17
			if diamonds:
				var p := c + Vector2(x, -0.02) * s
				var d := s * 0.07
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), silver)
			else:
				draw_rect(Rect2(c + Vector2(x - 0.05, -0.2) * s, Vector2(0.1, 0.36) * s), silver)
	else:
		# Generales: 1-4 estrellas doradas.
		var n := level - 17
		for i in n:
			var x := (float(i) - (n - 1) * 0.5) * (0.2 if n > 2 else 0.24)
			_star(c + Vector2(x, -0.03) * s, s * (0.1 if n > 2 else 0.12), gold)


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
