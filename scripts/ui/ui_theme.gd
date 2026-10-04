class_name UiTheme
## Tema visual de la interfaz: consola militar sci-fi oscura y legible (19.1), al estilo de los MMO de naves.
## Tipografía Chakra Petch (assets/fonts, licencia SIL OFL): SemiBold en mayúsculas para títulos, botones,
## pestañas y cifras; Medium para el texto corrido.
## Botones y paneles biselados: degradado vertical, borde luminoso y esquinas cortadas en diagonal.

const BG := Color("070b14")
const PANEL := Color(0.05, 0.07, 0.12, 0.94)
const PANEL_LIGHT := Color(0.09, 0.12, 0.19, 0.96)
const BORDER := Color("27405e")
const ACCENT := Color("4affff")
const ACCENT2 := Color("ff4fd8")
const TEXT := Color("dce6f5")
const MUTED := Color("7d8aa3")
const GOOD := Color("6fd17a")
const BAD := Color("ff5a5a")
const WARN := Color("ffb84a")
const GOLD := Color("ffd27a")

const DISPLAY_FONT := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const BODY_FONT := "res://assets/fonts/ChakraPetch-Medium.ttf"
const DISPLAY_MIN := 15          # desde este tamaño las etiquetas usan la tipografía de títulos

static var _display: Font
static var _body: Font
static var _bevels: Dictionary = {}


## Tipografía de títulos; los caracteres que no tiene (★, ✔, flechas…) caen en la fuente de Godot.
static func display_font() -> Font:
	if _display == null:
		_display = _load_font(DISPLAY_FONT)
	return _display


## Tipografía del texto corrido (tema por defecto de toda la interfaz).
static func body_font() -> Font:
	if _body == null:
		_body = _load_font(BODY_FONT)
	return _body


static func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var f: Font = load(path)
	if f is FontFile:
		(f as FontFile).fallbacks = [ThemeDB.fallback_font]
	return f


static func box(bg: Color, border: Color = BORDER, radius: int = 6, bw: int = 1, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Textura biselada (9 porciones): degradado de arriba a abajo, filete claro arriba, borde de color y
## esquinas superior izquierda e inferior derecha cortadas en diagonal.
static func bevel_tex(top: Color, bottom: Color, border: Color, cut: int = 7) -> Texture2D:
	var key := "%s|%s|%s|%d" % [top.to_html(), bottom.to_html(), border.to_html(), cut]
	if _bevels.has(key):
		return _bevels[key]
	var w := 48
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var fill := top.lerp(bottom, float(y) / (h - 1))
		for x in w:
			# Distancia a las diagonales de las dos esquinas cortadas.
			var tl := x + y - cut
			var br := (w - 1 - x) + (h - 1 - y) - cut
			if tl < 0 or br < 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1 or tl == 0 or br == 0
			var c := fill
			if edge:
				c = border
			elif y == 1 or tl == 1:
				c = fill.lerp(Color.WHITE, 0.18)   # filete de luz
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_bevels[key] = t
	return t


static func bevel(top: Color, bottom: Color, border: Color, pad: int = 10, cut: int = 7) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = bevel_tex(top, bottom, border, cut)
	s.texture_margin_left = cut + 3
	s.texture_margin_right = cut + 3
	s.texture_margin_top = cut + 3
	s.texture_margin_bottom = cut + 3
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## Estilos de botón: normal (acero azul), primary (cian luminoso), gold (compra/premium), danger.
static func button_styles(kind: String = "normal") -> Dictionary:
	match kind:
		"primary":
			return {"normal": bevel(Color("12606a"), Color("083038"), ACCENT), "hover": bevel(Color("1a8592"), Color("0c4650"), Color.WHITE),
				"pressed": bevel(Color("083038"), Color("12606a"), ACCENT), "disabled": bevel(Color("101820"), Color("0a1016"), Color("2a3a48"))}
		"gold":
			return {"normal": bevel(Color("6a4a12"), Color("382408"), GOLD), "hover": bevel(Color("92681a"), Color("4e330c"), Color.WHITE),
				"pressed": bevel(Color("382408"), Color("6a4a12"), GOLD), "disabled": bevel(Color("1a1610"), Color("100d08"), Color("3a3020"))}
		"danger":
			return {"normal": bevel(Color("6a1a1a"), Color("380a0a"), BAD), "hover": bevel(Color("922626"), Color("4e1010"), Color.WHITE),
				"pressed": bevel(Color("380a0a"), Color("6a1a1a"), BAD), "disabled": bevel(Color("1a1010"), Color("100808"), Color("3a2020"))}
	return {"normal": bevel(Color("1c2a40"), Color("0d1524"), BORDER), "hover": bevel(Color("26405e"), Color("132238"), ACCENT),
		"pressed": bevel(Color("0d1524"), Color("1c2a40"), ACCENT), "disabled": bevel(Color("0c111a"), Color("080c12"), Color("1c2636"))}


static func style_button(b: Button, kind: String = "normal") -> void:
	var st := button_styles(kind)
	for k in st.keys():
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", display_font())
	b.text = b.text.to_upper()


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.default_font = body_font()
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "Panel", box(PANEL))
	var st := button_styles()
	for k in st.keys():
		t.set_stylebox(k, "Button", st[k])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", display_font())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font("font", "CheckBox", display_font())
	t.set_font("font", "TabBar", display_font())
	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 6, 1, 10))
	t.set_stylebox("tab_selected", "TabContainer", bevel(Color("1a8592"), Color("0c4650"), ACCENT))
	t.set_stylebox("tab_unselected", "TabContainer", bevel(Color("1c2a40"), Color("0d1524"), BORDER))
	t.set_stylebox("tab_hovered", "TabContainer", bevel(Color("26405e"), Color("132238"), ACCENT))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), BORDER, 2, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 2, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", bevel(Color("101a2a"), Color("070c16"), ACCENT, 8, 5))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.04, 0.07), BORDER, 2, 1, 6))
	t.set_stylebox("normal", "SpinBox", box(Color(0.03, 0.04, 0.07), BORDER, 2, 1, 6))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.3), ACCENT, 2, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, ACCENT, 2, 0, 0))
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.6), BORDER, 2, 1, 2))
	return t


static func apply_root(win: Window) -> void:
	win.theme = build()


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= DISPLAY_MIN:
		# La tipografía propia se usa siempre en mayúsculas (estilo consola militar).
		l.add_theme_font_override("font", display_font())
		l.uppercase = true
	return l


## Título de sección: tipografía propia, mayúsculas y sombra de neón.
static func heading(text: String, size: int = 22, color: Color = ACCENT) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
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
