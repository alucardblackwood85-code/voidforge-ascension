class_name InventoryPanel
extends PanelContainer
## Ventana INVENTARIO / REFINADO durante la incursión (tecla I).
## Muestra la bodega y permite tirar materiales o refinarlos:
##  · Escudo: +% de escudo máximo durante 5 min por unidad (más raro → más %).
##  · Láser: +% de daño en un disparo de láser por unidad.

var sector: Sector
var list: VBoxContainer
var cargo_label: Label
var cargo_bar: ProgressBar
var buffs_label: RichTextLabel
var _version := -1


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.05, 0.09, 0.95), UiTheme.ACCENT, 8, 1, 12))
	custom_minimum_size = Vector2(560, 0)
	var v := W.vbox(8)
	add_child(v)
	var head := W.hbox(8)
	head.add_child(UiTheme.label("INVENTARIO / REFINADO", 20, UiTheme.ACCENT))
	head.add_child(W.spacer())
	head.add_child(W.button("✕", func(): visible = false))
	v.add_child(head)
	cargo_label = UiTheme.label("", 15)
	v.add_child(cargo_label)
	cargo_bar = ProgressBar.new()
	cargo_bar.show_percentage = false
	cargo_bar.custom_minimum_size = Vector2(0, 10)
	v.add_child(cargo_bar)
	buffs_label = UiTheme.rich("", 14)
	v.add_child(buffs_label)
	var help := UiTheme.label("Escudo: +% durante 5 min por unidad · Láser: +% de daño en 1 disparo por unidad · Más raro = más bonificación", 12, UiTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	list = W.vbox(4)
	var sc := W.scroll(list)
	sc.custom_minimum_size = Vector2(0, 360)
	v.add_child(sc)


func _process(_delta: float) -> void:
	if not visible:
		return
	var cap := sector.cargo_capacity()
	cargo_label.text = "Bodega: %d / %d u" % [sector.cargo_used, cap]
	cargo_bar.max_value = cap
	cargo_bar.value = sector.cargo_used
	var sb: Dictionary = sector.shield_buff
	var lb: Dictionary = sector.laser_buff
	var t := int(sb["time"])
	buffs_label.text = "[color=#3aa0ff]Escudo refinado: %s[/color]     [color=#ff6a6a]Láser refinado: %s[/color]" % [
		("+%.1f%% · %d:%02d" % [sb["pct"] * 100.0, t / 60, t % 60]) if t > 0 else "inactivo",
		("+%.1f%% · %d disparos" % [lb["pct"] * 100.0, lb["charges"]]) if lb["charges"] > 0 else "inactivo"]
	if _version != sector.loot_version:
		_version = sector.loot_version
		_rebuild()


func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	var mats := sector.cargo_materials()
	if mats.is_empty():
		list.add_child(UiTheme.label("La bodega está vacía. Haz clic en las cajas de botín para recogerlas.", 14, UiTheme.MUTED))
		return
	for mat in mats:
		var q := int(sector.loot[mat])
		var r: int = GameData.MATERIALS.get(mat, {}).get("rarity", 0)
		var row := W.card(Color(0.05, 0.08, 0.13, 0.9), GameData.RARITY_COLORS[r].darkened(0.3), 4)
		var h := W.hbox(6)
		row.add_child(h)
		var ic := W.icon("mat", mat)
		if ic:
			h.add_child(W.pic(ic, Vector2(34, 34)))
		var nv := W.vbox(0)
		nv.add_child(UiTheme.label("%s  x%d" % [GameData.mat_name(mat), q], 14, GameData.RARITY_COLORS[r]))
		nv.add_child(UiTheme.label("Escudo +%d%% · Láser +%d%%" % [int(GameData.REFINE_SHIELD_PCT[r] * 100), int(GameData.REFINE_LASER_PCT[r] * 100)], 11, UiTheme.MUTED))
		nv.custom_minimum_size.x = 190
		h.add_child(nv)
		h.add_child(W.spacer())
		for spec in [["Escudo", "shield", Color("3aa0ff")], ["Láser", "laser", Color("ff6a6a")]]:
			for n in [1, 10]:
				if n > q and n > 1:
					continue
				var b := _btn("%s x%d" % [spec[0], n], spec[2])
				var kind: String = spec[1]
				b.pressed.connect(func(): sector.refine(mat, n, kind))
				h.add_child(b)
		var drop := _btn("Tirar 10" if q > 10 else "Tirar", UiTheme.BAD)
		drop.pressed.connect(func(): sector.jettison(mat, 10))
		h.add_child(drop)
		var all := _btn("Todo", UiTheme.BAD)
		all.tooltip_text = "Tirar todo el material"
		all.pressed.connect(func(): sector.jettison(mat, q))
		h.add_child(all)
		list.add_child(row)


func _btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", col.lightened(0.3))
	return b
