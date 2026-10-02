class_name DropZone
extends PanelContainer
## Zona del inventario: soltar aquí un objeto sacado de un slot lo desequipa.

signal received(data: Dictionary)

var kind := ""
var hover := false


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	hover = data is Dictionary and data.get("kind", "") == kind and int(data.get("from_slot", -1)) >= 0
	queue_redraw()
	return hover


func _drop_data(_pos: Vector2, data: Variant) -> void:
	hover = false
	received.emit(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		hover = false
		queue_redraw()


func _draw() -> void:
	if hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.4, 0.3, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BAD, false, 2.0)
