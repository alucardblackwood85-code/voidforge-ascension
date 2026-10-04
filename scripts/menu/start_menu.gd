class_name StartMenu
extends Control
## Pantalla de INICIO (antes "hangar"): navegación entre Hangar, Equipamiento, Tienda, Crafteo,
## Estadísticas, Códex y Ajustes, con el botón JUGAR que abre el mapa estelar.

signal launch_requested(params: Dictionary)

# Pestañas principales en el orden de uso: preparar la nave, conseguir equipo, mejorar la cuenta y
# consultar; Ajustes va aparte, a la derecha.
const PAGES := [
	["hangar", "Hangar"], ["equip", "Equipamiento"], ["shop", "Tienda"], ["craft", "Fabricación"],
	["ascent", "Ascenso"], ["missions", "Misiones"], ["codex", "Códex"], ["stats", "Estadísticas"],
]

var page_id := "hangar"
## Estado de navegación compartido entre páginas (pestañas internas, selección…).
var state := {"ship": "", "equip_tab": "ship", "equip_filter": "lasers", "shop_tab": "ship", "craft_tab": "ammo", "biome": "ferron", "level": 1}
var content_holder: MarginContainer
var nav: HBoxContainer
var info_bar: HBoxContainer
var page: Control
var _dirty := false


func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit)
	var bg_col := ColorRect.new()
	bg_col.color = UiTheme.BG
	bg_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_col)
	if ResourceLoader.exists("res://assets/backgrounds/menu.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/backgrounds/menu.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.55, 0.6, 0.7)
		add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var root := W.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# Barra superior
	var top := PanelContainer.new()
	var tsb := UiTheme.box(Color(0.02, 0.035, 0.07, 0.95), Color(0.15, 0.3, 0.45), 0, 0, 10)
	tsb.border_width_bottom = 2
	tsb.border_color = Color(UiTheme.ACCENT, 0.35)
	top.add_theme_stylebox_override("panel", tsb)
	root.add_child(top)
	var top_v := W.vbox(8)
	top.add_child(top_v)
	info_bar = W.hbox(16)
	top_v.add_child(info_bar)
	nav = W.hbox(4)
	top_v.add_child(nav)
	# Contenido
	content_holder = MarginContainer.new()
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content_holder.add_theme_constant_override("margin_" + side, 14)
	root.add_child(content_holder)

	state["ship"] = GameState.data["current_ship"]
	state["level"] = int(GameState.data["sector_max"])
	GameState.changed.connect(_on_changed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="):
			state["missions_tab"] = arg.get_slice("=", 1)
		if arg.begins_with("--page="):
			page_id = arg.get_slice("=", 1)
	refresh()
	Music.play("menu")
	_show_rank_rewards.call_deferred()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _on_changed() -> void:
	# Agrupa varios cambios del mismo frame en una sola reconstrucción.
	if not _dirty:
		_dirty = true
		refresh.call_deferred()


func show_page(id: String) -> void:
	page_id = id
	Sfx.play("ui_click")
	refresh()


func refresh() -> void:
	_dirty = false
	_build_info()
	_build_nav()
	if page:
		page.queue_free()
	match page_id:
		"hangar":
			page = PageHangar.new()
		"equip":
			page = PageEquip.new()
		"shop":
			page = PageShop.new()
		"craft":
			page = PageCraft.new()
		"missions":
			page = PageMissions.new()
		"stats":
			page = PageStats.new()
		"codex":
			page = PageCodex.new()
		"settings":
			page = PageSettings.new()
		"ascent":
			page = PageAscent.new()
		"play":
			page = PageStarmap.new()
	page.set("menu", self)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_child(page)


func _build_info() -> void:
	for c in info_bar.get_children():
		c.queue_free()
	var logo := W.hbox(10)
	logo.add_child(UiTheme.heading("Voidforge", 32, UiTheme.ACCENT))
	logo.add_child(UiTheme.heading("Ascension", 32, UiTheme.ACCENT2))
	info_bar.add_child(logo)
	info_bar.add_child(W.spacer())
	# Monedas en cápsulas biseladas con su icono.
	for k in ["credits", "nexo", "seals"]:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.08, 0.11, 0.18), Color(0.03, 0.05, 0.09), UiTheme.BORDER, 6, 6))
		pill.tooltip_text = GameData.mat_name(k)
		var h := W.hbox(6)
		pill.add_child(h)
		var ic := W.icon("mat", k)
		if ic:
			h.add_child(W.pic(ic, Vector2(24, 24)))
		else:
			h.add_child(UiTheme.label(GameData.mat_name(k), 12, UiTheme.MUTED))
		var v := UiTheme.label(GameData.format_num(GameState.get_amount(k)), 20, GameData.mat_color(k) if k != "seals" else UiTheme.WARN)
		v.add_theme_font_override("font", UiTheme.display_font())
		h.add_child(v)
		info_bar.add_child(pill)
	var lvl := GameState.level()
	info_bar.add_child(RankBadge.make(lvl, 44))
	var rv := W.vbox(0)
	rv.add_child(UiTheme.label(GameState.rank_name(), 15, UiTheme.WARN))
	var nxt := GameData.xp_for_level(lvl + 1) if lvl < GameData.MAX_LEVEL else int(GameState.data["xp"])
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 8)
	bar.show_percentage = false
	bar.min_value = GameData.xp_for_level(lvl)
	bar.max_value = maxi(nxt, int(bar.min_value) + 1)
	bar.value = int(GameState.data["xp"])
	rv.add_child(bar)
	rv.add_child(UiTheme.label("Nivel %d · %s / %s XP" % [lvl, GameData.format_num(GameState.data["xp"]), GameData.format_num(nxt)], 11, UiTheme.MUTED))
	info_bar.add_child(rv)
	var play := W.btn("Jugar  >", func(): show_page("play"), "gold", 190, 26)
	play.custom_minimum_size.y = 52
	info_bar.add_child(play)


func _build_nav() -> void:
	for c in nav.get_children():
		c.queue_free()
	for p in PAGES:
		var label: String = p[1]
		var id: String = p[0]
		if id == "missions":
			var pend := Prog.unclaimed_count() + maxi(0, Prog.season_tier() - int(GameState.data["season"]["claimed"]))
			if pend > 0:
				label = "Misiones (%d)" % pend
		if id == "ascent" and GameState.ascent_free() > 0:
			label = "Ascenso (%d)" % GameState.ascent_free()
		var b := W.btn(label, func(): show_page(id), "primary" if id == page_id else "normal", 0, 17)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 40
		if id == "missions" and label != "Misiones":
			b.add_theme_color_override("font_color", UiTheme.GOOD)
		nav.add_child(b)
	nav.add_child(W.spacer())
	var cfg := W.btn("Ajustes", func(): show_page("settings"), "primary" if page_id == "settings" else "normal", 0, 17)
	cfg.focus_mode = Control.FOCUS_NONE
	cfg.custom_minimum_size.y = 40
	nav.add_child(cfg)


func launch(params: Dictionary) -> void:
	GameState.save_game()
	Sfx.play("warp")
	launch_requested.emit(params)


## M3/M13: al volver al INICIO muestra los ascensos y logros pendientes con sus recompensas.
func _show_rank_rewards() -> void:
	var log: Array = GameState.data.get("rank_log", [])
	var ach: Array = GameState.data.get("ach_log", [])
	var news: Array = GameState.data.get("news", [])
	if log.is_empty() and ach.is_empty() and news.is_empty():
		return
	var txt := ""
	for e in log:
		txt += "%s (nivel %d): %s\n" % [GameState.rank_name(int(e["level"])), int(e["level"]), ", ".join(e["rewards"])]
	for a in ach:
		txt += "🏆 Logro: %s\n" % a
	for n in news:
		txt += "%s\n" % n
	GameState.data["rank_log"] = []
	GameState.data["ach_log"] = []
	GameState.data["news"] = []
	GameState.save_game()
	var dlg := AcceptDialog.new()
	dlg.title = "¡Ascenso!" if not log.is_empty() else ("¡Logro desbloqueado!" if not ach.is_empty() else "Novedades")
	dlg.dialog_text = txt.strip_edges()
	add_child(dlg)
	dlg.popup_centered()
	Sfx.play("objective")
