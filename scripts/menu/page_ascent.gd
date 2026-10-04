class_name PageAscent
extends VBoxContainer
## ASCENSO: puntos de ascenso, mejoras permanentes de la nave y de la cuenta (inspirado en los puntos
## de investigación de los MMO de naves). Los puntos se compran con Cristales Nexo, cada uno algo más
## caro que el anterior, y se reparten entre 13 mejoras de 5 niveles en tres ramas.

var menu: StartMenu


## Barra de niveles: rombos llenos hasta el nivel actual.
class Pips extends Control:
	var level := 0
	var color := UiTheme.ACCENT

	func _draw() -> void:
		for k in GameData.ASCENT_MAX:
			var c := Vector2(10 + k * 22, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)])
			if k < level:
				draw_colored_polygon(pts, color)
			else:
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color, 0.35), 1.5, true)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var a: Dictionary = GameState.data.get("ascent", {"points": 0})
	var bought := int(a.get("points", 0))
	var total := GameState.ascent_total_points()
	# Cabecera: resumen y compra de puntos.
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.07, 0.05, 0.14, 0.96), Color(0.03, 0.02, 0.07, 0.96), UiTheme.ACCENT2, 12, 10))
	var hh := W.hbox(18)
	head.add_child(hh)
	var hv := W.vbox(4)
	hv.add_child(UiTheme.heading("Puntos de ascenso", 28, UiTheme.ACCENT2))
	var d := UiTheme.label("Mejoras permanentes para todas tus naves y tu cuenta. Compra puntos con Cristales Nexo (cada uno cuesta 1 más que el anterior) y repártelos entre las mejoras; cada una llega al nivel %d." % GameData.ASCENT_MAX, 14, UiTheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 620
	hv.add_child(d)
	hh.add_child(hv)
	hh.add_child(W.spacer())
	var nums := W.vbox(2)
	nums.add_child(W.stat_row("Puntos comprados", "%d / %d" % [bought, total], false))
	nums.add_child(W.stat_row("Puntos libres", str(GameState.ascent_free()), true, UiTheme.GOOD if GameState.ascent_free() > 0 else UiTheme.TEXT))
	nums.custom_minimum_size.x = 260
	hh.add_child(nums)
	var bv := W.vbox(6)
	if bought < total:
		var cost := GameState.ascent_point_cost()
		var buy := W.btn("Comprar punto · %d Nexo" % cost, func():
			if GameState.buy_ascent_point():
				Sfx.play("pickup_rare")
			else:
				Sfx.play("ui_error"), "gold", 260, 17)
		buy.disabled = GameState.get_amount("nexo") < cost
		buy.tooltip_text = "Tienes %d Cristales Nexo" % GameState.get_amount("nexo")
		bv.add_child(buy)
	else:
		bv.add_child(UiTheme.heading("Todos los puntos comprados", 16, UiTheme.GOOD))
	var rs := W.btn("Reasignar todo · %d Nexo" % GameData.ASCENT_RESET, func():
		if GameState.ascent_reset():
			Sfx.play("ui_select")
		else:
			Sfx.play("ui_error"), "danger", 260, 14)
	rs.disabled = GameState.ascent_free() == bought
	bv.add_child(rs)
	hh.add_child(bv)
	add_child(head)
	# Ramas
	var cols := W.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var colors := {"Nave": UiTheme.ACCENT, "Combate": Color("ff7a5a"), "Cuenta": UiTheme.GOLD}
	for group in ["Nave", "Combate", "Cuenta"]:
		var fr: Array = W.frame(group, colors[group])
		fr[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var list := W.vbox(8)
		for id in GameData.ASCENT_SKILLS.keys():
			var sk: Dictionary = GameData.ASCENT_SKILLS[id]
			if sk["group"] == group:
				list.add_child(_skill(id, sk, colors[group]))
		fr[1].add_child(W.scroll(list))
		cols.add_child(fr[0])
	add_child(cols)


func _skill(id: String, sk: Dictionary, col: Color) -> Control:
	var lvl := GameState.ascent_level(id)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.07, 0.1, 0.16), Color(0.04, 0.06, 0.1), col.darkened(0.4) if lvl > 0 else UiTheme.BORDER, 8, 7))
	var h := W.hbox(10)
	c.add_child(h)
	var v := W.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiTheme.label(sk["name"], 17, col.lightened(0.25) if lvl > 0 else UiTheme.TEXT))
	var per: float = sk["per"]
	var now: String = sk["desc"] % ("%s%%" % _pct(per * lvl))
	var nxt: String = ("  →  " + sk["desc"] % ("%s%%" % _pct(per * (lvl + 1)))) if lvl < GameData.ASCENT_MAX else "  (máximo)"
	v.add_child(UiTheme.label((now if lvl > 0 else "Sin mejorar") + nxt, 13, UiTheme.MUTED))
	var pips := Pips.new()
	pips.level = lvl
	pips.color = col
	pips.custom_minimum_size = Vector2(120, 20)
	v.add_child(pips)
	h.add_child(v)
	var add := W.btn("+", func():
		if GameState.ascent_add(id):
			Sfx.play("ui_select"), "primary", 46, 22)
	add.disabled = GameState.ascent_free() <= 0 or lvl >= GameData.ASCENT_MAX
	add.tooltip_text = "Asignar un punto" if not add.disabled else ("Nivel máximo" if lvl >= GameData.ASCENT_MAX else "Compra un punto primero")
	h.add_child(add)
	return c


func _pct(f: float) -> String:
	var v := f * 100.0
	return ("%d" % int(round(v))) if absf(v - round(v)) < 0.05 else ("%.1f" % v)
