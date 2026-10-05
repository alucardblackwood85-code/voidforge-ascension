extends Control
## Comparación de texturas: el modelo actual del hangar frente a la versión de prueba (assets/models/_test),
## girando. Captura con: godot --path . res://tools/tex_compare.tscn -- --cmp=<id>:<archivo prueba> --shot=...
var spins: Array = []
var t := 0.0


func _ready() -> void:
	var id := "kestrel_a1"
	var test := "kestrel_t1.glb"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cmp="):
			id = a.get_slice("=", 1).get_slice(":", 0)
			test = a.get_slice("=", 1).get_slice(":", 1)
	var bg := ColorRect.new()
	bg.color = Color("0b1322")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in 2:
		var s := ShipSpin.make(id, Vector2(620, 600), 0.95)
		if i == 1:
			for c in s.get_children():
				c.queue_free()
			s.pivot = null
			s.set_meta("test", "res://assets/models/_test/" + test)
		s.position = Vector2(20 + i * 640, 80)
		s.size = Vector2(620, 600)
		add_child(s)
		spins.append(s)
		var l := UiTheme.heading("Actual (sprite proyectado)" if i == 0 else "Prueba Tripo: " + test, 22, UiTheme.GOLD)
		l.position = Vector2(30 + i * 640, 20)
		add_child(l)
	await get_tree().process_frame
	var s2: ShipSpin = spins[1]
	s2._build_3d_from(String(s2.get_meta("test")))


func _process(delta: float) -> void:
	t += delta
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			# --shots=ruta_base: guarda capturas a los 2 y 5 s y cierra.
			var base := a.get_slice("=", 1)
			for st in [2.0, 5.0]:
				if t >= st and not has_meta("s%d" % int(st)):
					set_meta("s%d" % int(st), true)
					get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, int(st)])
			if t >= 5.2:
				get_tree().quit()
