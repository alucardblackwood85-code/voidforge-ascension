class_name DropSlot
extends PanelContainer
## Slot de equipamiento que acepta objetos arrastrados del tipo correcto (láser → slot de láser, etc.).
## También se puede arrastrar desde el slot (para mover o quitar) y clic derecho lo vacía.

signal dropped(slot: DropSlot, data: Dictionary)
signal cleared(slot: DropSlot)

var kind := ""
var index := 0
var uid := -1
var entry = null
var label_text := ""
var hover_ok := false


static func make(p_kind: String, p_index: int, p_uid: int, p_info: Dictionary, p_label: String) -> DropSlot:
	var s := DropSlot.new()
	s.kind = p_kind
	s.index = p_index
	s.uid = p_uid
	s.label_text = p_label
	s._build(p_info)
	return s


func _build(info: Dictionary) -> void:
	custom_minimum_size = Vector2(96, 112)
	var filled := not info.is_empty()
	var col: Color = info.get("color", UiTheme.BORDER) if filled else Color(0.25, 0.32, 0.45)
	var style := UiTheme.box(Color(0.03, 0.05, 0.09, 0.9), col, 6, 2 if filled else 1, 4)
	if not filled:
		style.border_color = Color(0.3, 0.4, 0.55, 0.8)
		style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	tooltip_text = info.get("tip", "Slot vacío — arrastra aquí un objeto compatible")
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	if filled:
		var tex: Texture2D = info.get("icon")
		if tex:
			v.add_child(W.pic(tex, Vector2(80, 64)))
		var l := UiTheme.label(info.get("name", ""), 12, col.lightened(0.35))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 88
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	else:
		var plus := UiTheme.label("+", 34, Color(0.35, 0.45, 0.6))
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(plus)
	var tag := UiTheme.label(label_text, 11, UiTheme.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag)


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	hover_ok = data is Dictionary and data.get("kind", "") == kind
	queue_redraw()
	return hover_ok


func _drop_data(_pos: Vector2, data: Variant) -> void:
	hover_ok = false
	dropped.emit(self, data)


func _get_drag_data(_pos: Vector2) -> Variant:
	if uid < 0 and entry == null:
		return null
	var prev := duplicate() as Control
	prev.modulate = Color(1, 1, 1, 0.8)
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = -custom_minimum_size * 0.5
	set_drag_preview(holder)
	return {"kind": kind, "uid": uid, "entry": entry, "from_slot": index}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and (uid >= 0 or entry != null):
		cleared.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		hover_ok = false
		queue_redraw()


func _draw() -> void:
	if hover_ok:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 1.0, 0.8, 0.18))
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.ACCENT, false, 3.0)
