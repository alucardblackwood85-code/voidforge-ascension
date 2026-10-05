extends Control
## Vídeo de revisión del hangar 3D: cada nave gira 5 s en el visor del juego (ShipSpin) con su nombre.
## Se graba con el Movie Maker de Godot:
##   godot --path . --write-movie build/hangar_reel.avi --fixed-fps 30 --resolution 1280x720 res://tools/hangar_reel.tscn
## (tools/ queda fuera de la exportación web).

const SECS := 5.0
var ids: Array = []
var idx := -1
var t := 0.0
var spin: ShipSpin = null
var title: Label


func _ready() -> void:
	ids = GameData.SHIPS.keys()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/hangar.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	title = UiTheme.heading("", 34, UiTheme.GOLD)
	title.position = Vector2(30, 20)
	add_child(title)
	_next()


func _next() -> void:
	idx += 1
	if idx >= ids.size():
		get_tree().quit()
		return
	if spin:
		spin.queue_free()
	var id: String = ids[idx]
	spin = ShipSpin.make(id, Vector2(1100, 640), 0.9)
	spin.position = Vector2(90, 60)
	spin.size = Vector2(1100, 640)
	spin.idle = 10.0
	add_child(spin)
	title.text = "%d/%d  %s" % [idx + 1, ids.size(), GameData.SHIPS[id]["name"]]
	t = 0.0


func _process(delta: float) -> void:
	t += delta
	if spin:
		spin.angle += 72.0 * delta - ShipSpin.AUTO_SPEED * delta   # una vuelta en 5 s
	if t >= SECS:
		_next()
