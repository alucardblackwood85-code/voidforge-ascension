class_name StartMenu
extends Control
## Pantalla de INICIO (antes "hangar"): navegación entre Hangar, Equipamiento, Tienda, Crafteo,
## Estadísticas, Códex y Ajustes, con el botón JUGAR que abre el mapa estelar.

signal launch_requested(params: Dictionary)

const PAGES := [
	["hangar", "HANGAR"], ["equip", "EQUIPAMIENTO"], ["shop", "TIENDA"], ["craft", "CRAFTEO"],
	["missions", "MISIONES"], ["stats", "ESTADÍSTICAS"], ["codex", "CÓDEX"], ["settings", "AJUSTES"],
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
	top.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.04, 0.08, 0.92), Color(0.15, 0.3, 0.45), 0, 1, 10))
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
		"play":
			page = PageStarmap.new()
	page.set("menu", self)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_child(page)


func _build_info() -> void:
	for c in info_bar.get_children():
		c.queue_free()
	info_bar.add_child(UiTheme.label("VOIDFORGE", 28, UiTheme.ACCENT))
	info_bar.add_child(UiTheme.label("ASCENSION", 28, UiTheme.ACCENT2))
	info_bar.add_child(W.spacer())
	for k in ["credits", "nexo", "seals"]:
		var h := W.hbox(4)
		h.add_child(UiTheme.label(GameData.mat_name(k), 14, UiTheme.MUTED))
		h.add_child(UiTheme.label(GameData.format_num(GameState.get_amount(k)), 18, GameData.mat_color(k) if k != "seals" else UiTheme.WARN))
		info_bar.add_child(h)
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
	var play := W.button("  ▶  JUGAR  ", func(): show_page("play"), true, 170)
	play.custom_minimum_size.y = 48
	play.add_theme_font_size_override("font_size", 22)
	info_bar.add_child(play)


func _build_nav() -> void:
	for c in nav.get_children():
		c.queue_free()
	for p in PAGES:
		var b := Button.new()
		b.text = "  %s  " % p[1]
		if p[0] == "missions":
			var pend := Prog.unclaimed_count() + maxi(0, Prog.season_tier() - int(GameState.data["season"]["claimed"]))
			if pend > 0:
				b.text = "  MISIONES (%d)  " % pend
				b.add_theme_color_override("font_color", UiTheme.GOOD)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 36
		var active: bool = p[0] == page_id
		if active:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.06, 0.25, 0.3), UiTheme.ACCENT, 4, 2, 8))
			b.add_theme_color_override("font_color", Color.WHITE)
		var id: String = p[0]
		b.pressed.connect(func(): show_page(id))
		nav.add_child(b)


func launch(params: Dictionary) -> void:
	GameState.save_game()
	Sfx.play("warp")
	launch_requested.emit(params)


## M3/M13: al volver al INICIO muestra los ascensos y logros pendientes con sus recompensas.
func _show_rank_rewards() -> void:
	var log: Array = GameState.data.get("rank_log", [])
	var ach: Array = GameState.data.get("ach_log", [])
	if log.is_empty() and ach.is_empty():
		return
	var txt := ""
	for e in log:
		txt += "%s (nivel %d): %s\n" % [GameState.rank_name(int(e["level"])), int(e["level"]), ", ".join(e["rewards"])]
	for a in ach:
		txt += "🏆 Logro: %s\n" % a
	GameState.data["rank_log"] = []
	GameState.data["ach_log"] = []
	GameState.save_game()
	var dlg := AcceptDialog.new()
	dlg.title = "¡Ascenso!" if not log.is_empty() else "¡Logro desbloqueado!"
	dlg.dialog_text = txt.strip_edges()
	add_child(dlg)
	dlg.popup_centered()
	Sfx.play("objective")
