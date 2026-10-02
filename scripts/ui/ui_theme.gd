class_name UiTheme
## Tema visual de la interfaz: sci-fi oscuro y legible (19.1).

const BG := Color("0b0f1a")
const PANEL := Color(0.06, 0.08, 0.13, 0.94)
const PANEL_LIGHT := Color(0.10, 0.13, 0.20, 0.96)
const BORDER := Color("2a3a5a")
const ACCENT := Color("4affff")
const ACCENT2 := Color("ff4fd8")
const TEXT := Color("dce6f5")
const MUTED := Color("7d8aa3")
const GOOD := Color("6fd17a")
const BAD := Color("ff5a5a")
const WARN := Color("ffb84a")


static func box(bg: Color, border: Color = BORDER, radius: int = 6, bw: int = 1, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "Panel", box(PANEL))
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, BORDER, 5, 1, 8))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.2, 0.3), ACCENT, 5, 1, 8))
	t.set_stylebox("pressed", "Button", box(Color(0.1, 0.3, 0.35), ACCENT, 5, 2, 8))
	t.set_stylebox("disabled", "Button", box(Color(0.06, 0.07, 0.1), Color(0.15, 0.18, 0.25), 5, 1, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 5, 1, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 6, 1, 10))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.12, 0.18, 0.28), ACCENT, 4, 1, 10))
	t.set_stylebox("tab_unselected", "TabContainer", box(PANEL_LIGHT, BORDER, 4, 1, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.14, 0.2, 0.3), ACCENT, 4, 1, 10))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), BORDER, 3, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 3, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.04, 0.05, 0.09, 0.97), ACCENT, 4, 1, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.04, 0.07), BORDER, 4, 1, 6))
	t.set_stylebox("normal", "SpinBox", box(Color(0.03, 0.04, 0.07), BORDER, 4, 1, 6))
	return t


static func apply_root(win: Window) -> void:
	win.theme = build()


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): Sfx.play("ui_click"))
	b.pressed.connect(cb)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	return b


static func cost_text(cost: Dictionary, times: int = 1) -> String:
	var parts: PackedStringArray = []
	for k in cost.keys():
		var need := int(cost[k]) * times
		var have := GameState.get_amount(k)
		var col := "6fd17a" if have >= need else "ff5a5a"
		parts.append("[color=#%s]%s %s[/color]" % [col, GameData.format_num(need), GameData.mat_name(k)])
	return ", ".join(parts) if parts.size() > 0 else "Gratis"


static func rich(text: String, size: int = 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	r.custom_minimum_size.x = 200
	return r
