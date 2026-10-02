class_name AudioPanel
extends VBoxContainer
## Controles de volumen (General, Música, Efectos, Láseres, Voz). Se usa en Ajustes y en la pausa.

const CHANNELS := [["master", "General"], ["music", "Música"], ["sfx", "Efectos"], ["lasers", "Láseres"], ["voice", "Voz de la IA"]]


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var a: Dictionary = GameState.data["settings"]["audio"]
	for ch in CHANNELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiTheme.label(ch[1], 16)
		l.custom_minimum_size.x = 130
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = float(a.get(ch[0], 0.8))
		s.custom_minimum_size = Vector2(260, 28)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(s)
		var pct := UiTheme.label("%d%%" % int(s.value * 100), 15, UiTheme.MUTED)
		pct.custom_minimum_size.x = 50
		row.add_child(pct)
		var key: String = ch[0]
		s.value_changed.connect(func(v):
			Sfx.set_volume(key, v)
			pct.text = "%d%%" % int(v * 100)
			if key == "lasers":
				Sfx.play("laser_l01", null, 0.0, 0.0)
			elif key == "sfx":
				Sfx.play("pickup", null, 0.0, 0.0)
			elif key == "voice" and not s.has_meta("tested"):
				s.set_meta("tested", true)
				Sfx.voice("shield_down"))
		s.drag_ended.connect(func(_c): GameState.save_game())
		add_child(row)
