class_name DragItem
extends PanelContainer
## Ficha de objeto arrastrable (láser, generador, módulo, láser de dron, munición/objeto de barra).
## Datos de arrastre: {kind, uid | entry}. Doble clic: equipar en el primer slot libre.

signal activated(item: DragItem)

var kind := ""          # lasers | gens | mods | drone_lasers | hotbar
var uid := -1
var entry = null        # para la barra rápida: {"type": "ammo"/"item", "id": ...}
var info: Dictionary = {}
var dimmed := false


static func make(p_kind: String, p_uid: int, p_info: Dictionary, note: String = "") -> DragItem:
	var d := DragItem.new()
	d.kind = p_kind
	d.uid = p_uid
	d.info = p_info
	d._build(note)
	return d


func _build(note: String) -> void:
	custom_minimum_size = Vector2(96, 112)
	var col: Color = info.get("color", UiTheme.BORDER)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.08, 0.13, 0.95), col.darkened(0.2), 6, 2, 4))
	tooltip_text = info.get("tip", "")
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var tex: Texture2D = info.get("icon")
	if tex:
		var p := W.pic(tex, Vector2(80, 64))
		if info.has("tint"):
			p.self_modulate = Color.WHITE.lerp(info["tint"], 0.15)
		v.add_child(p)
	var l := UiTheme.label(info.get("name", "?"), 12, col.lightened(0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 88
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var lvl: int = info.get("level", -1)
	var sub := note if note != "" else ("Nv %d" % lvl if lvl >= 0 else "")
	if sub != "":
		var s := UiTheme.label(sub, 11, UiTheme.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	if dimmed:
		modulate = Color(1, 1, 1, 0.5)


func _get_drag_data(_pos: Vector2) -> Variant:
	var prev := duplicate() as Control
	prev.modulate = Color(1, 1, 1, 0.8)
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = -custom_minimum_size * 0.5
	set_drag_preview(holder)
	Sfx.play("ui_click")
	return {"kind": kind, "uid": uid, "entry": entry, "from_slot": -1}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(self)
		accept_event()
