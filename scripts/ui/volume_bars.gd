class_name VolumeBars
extends Control
## Indicador de volumen en 10 cuadritos (10% cada uno): grises apagados, celestes encendidos.
## Clic o arrastre sobre un cuadro fija el nivel; la rueda sube o baja de uno en uno; clic en el primero
## cuando es el único encendido lo deja en 0.

signal level_changed(level: int)
signal released

const COUNT := 10
const GAP := 5.0
const CUT := 3.0

var level := 8
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(COUNT * 24 + (COUNT - 1) * GAP, 24)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_level(v: int, emit := false) -> void:
	v = clampi(v, 0, COUNT)
	if v == level:
		return
	level = v
	queue_redraw()
	if emit:
		level_changed.emit(level)


func _cell_w() -> float:
	# Cuadritos: lado = alto del control (sin estirarse si sobra ancho).
	return minf(size.y, (size.x - (COUNT - 1) * GAP) / COUNT)


func _index_at(x: float) -> int:
	return clampi(int(x / (_cell_w() + GAP)), 0, COUNT - 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _index_at(mb.position.x)
			set_level(0 if i == 0 and level == 1 else i + 1, true)
			_dragging = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_level(level + 1, true)
			released.emit()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_level(level - 1, true)
			released.emit()
		accept_event()
	elif event is InputEventMouseButton and not event.pressed and _dragging:
		_dragging = false
		released.emit()
	elif event is InputEventMouseMotion and _dragging:
		var x: float = (event as InputEventMouseMotion).position.x
		set_level(0 if x < 0 else _index_at(x) + 1, true)


func _draw() -> void:
	var w := _cell_w()
	var h := size.y
	for i in COUNT:
		var x := i * (w + GAP)
		var on := i < level
		# Cuadro biselado: esquinas superior izquierda e inferior derecha cortadas, como los paneles.
		var pts := PackedVector2Array([Vector2(x + CUT, 0), Vector2(x + w, 0), Vector2(x + w, h - CUT),
			Vector2(x + w - CUT, h), Vector2(x, h), Vector2(x, CUT)])
		if on:
			draw_colored_polygon(pts, Color(UiTheme.ACCENT, 0.18))   # halo
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p.lerp(Vector2(x + w * 0.5, h * 0.5), 0.12))
			draw_colored_polygon(inner, UiTheme.ACCENT)
			draw_line(inner[0], inner[1], Color.WHITE.lerp(UiTheme.ACCENT, 0.4), 1.5)   # filete de luz
		else:
			draw_colored_polygon(pts, Color("1a2230"))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, UiTheme.ACCENT if on else Color("3a4658"), 1.0)
