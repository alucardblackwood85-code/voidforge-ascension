class_name ShipSpin
extends Control
## Visor del hangar: la nave gira en vista semifrontal sobre una plataforma holográfica, como en los MMO
## de naves, y se puede arrastrar con el ratón para girarla a mano.
## Con modelo 3D (assets/models/hangar/<id>.glb, exportado con tools/build_hangar_glb.ps1) la nave se
## dibuja en tiempo real: el giro es continuo y nítido. Si no hay modelo, usa la hoja de 36 fotogramas
## (assets/sprites/hangar/<id>.webp) mostrando un fotograma cada vez (sin fundidos, que dejaban restos de
## dos posiciones a la vez); sin hoja, el sprite plano con balanceo.

const COLS := 6
const FRAMES := 36
const AUTO_SPEED := 22.0      # grados por segundo

var ship_id := ""
var sheet: Texture2D
var flat: Texture2D
var angle := 200.0            # empieza de tres cuartos, con la proa hacia el espectador
var t := 0.0
var dragging := false
var idle := 0.0
var show_floor := true
var zoom := 1.0
var pivot: Node3D = null             # modelo 3D (si existe): se gira en _process


static func model_path(id: String) -> String:
	return "res://assets/models/hangar/%s.glb" % id


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(model_path(id))


static func has_sheet(id: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/hangar/%s.webp" % id)


static func make(id: String, size: Vector2, p_zoom: float = 1.0) -> ShipSpin:
	var s := ShipSpin.new()
	s.ship_id = id
	s.custom_minimum_size = size
	s.zoom = p_zoom
	if has_model(id):
		s._build_3d()
	elif has_sheet(id):
		s.sheet = load("res://assets/sprites/hangar/%s.webp" % id)
	else:
		s.flat = W.icon("ship", id)
	return s


## Un fotograma suelto de la hoja (para iconos en tres cuartos).
static func frame_tex(id: String, frame: int) -> Texture2D:
	if not has_sheet(id):
		return W.icon("ship", id)
	var sh: Texture2D = load("res://assets/sprites/hangar/%s.webp" % id)
	var fs := sh.get_width() / COLS
	var a := AtlasTexture.new()
	a.atlas = sh
	a.region = Rect2((frame % COLS) * fs, (frame / COLS) * fs, fs, fs)
	return a


## Escena 3D propia (mundo aparte, fondo transparente): cámara ortográfica a 26° de elevación como los
## renders del hangar, luz principal desde arriba a la izquierda, relleno y contraluz, y cielo en degradado
## sólo para los reflejos del metal.
func _build_3d() -> void:
	_build_3d_from(model_path(ship_id))


func _build_3d_from(path: String) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.65, 0.8)
	sky_mat.sky_horizon_color = Color(1.0, 0.97, 0.92)
	sky_mat.ground_horizon_color = Color(0.5, 0.52, 0.58)
	sky_mat.ground_bottom_color = Color(0.04, 0.05, 0.07)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 2.9 / zoom
	var elev := deg_to_rad(26.0)
	cam.position = Vector3(0.0, sin(elev), cos(elev)) * 6.0
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, -0.12, 0.0), Vector3.UP)
	for l in [[Vector3(-35.0, -135.0, 0.0), 2.0], [Vector3(-60.0, 60.0, 0.0), 0.7], [Vector3(20.0, 180.0, 0.0), 0.9]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		vp.add_child(d)
	pivot = Node3D.new()
	vp.add_child(pivot)
	var scn: PackedScene = load(path)
	if scn:
		var inst := scn.instantiate()
		pivot.add_child(inst)
		_tune_materials(inst)


## El cielo de Godot refleja más que el entorno de Blender: algo menos de metal para que se vean los colores.
func _tune_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if not (m is StandardMaterial3D):
				continue
			var sm: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			if sm.metallic_texture != null:
				# Textura PBR de Tripo: su mapa de metal llega a 1 en zonas blancas, que sin reflejos claros se
				# ven oscuras (Vanguard azul marino, Mule beige). El escalar multiplica el mapa: metal al 45%.
				# Metal satinado: el mapa de metal tal cual y la rugosidad del mapa al 55% (con 1,0 quedaba mate,
				# «de plastilina»), sin llegar a espejo.
				sm.metallic = 0.85
				sm.roughness = 0.55
				sm.metallic_specular = 0.6
			else:
				sm.metallic = 0.35
				sm.roughness = 0.4
				sm.emission_energy_multiplier = 1.6
			mi.set_surface_override_material(i, sm)
	for c in n.get_children():
		_tune_materials(c)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		idle = 0.0
	elif event is InputEventMouseMotion and dragging:
		angle -= event.relative.x * 0.6
		idle = 0.0


func _process(delta: float) -> void:
	t += delta
	idle += delta
	if not dragging and idle > 1.5:
		angle += AUTO_SPEED * delta
	if pivot:
		pivot.rotation.y = deg_to_rad(angle)
		pivot.position.y = sin(t * 1.4) * 0.03
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y * 1.6) * 0.42
	if show_floor:
		# Plataforma: elipse con anillos que laten y un haz de luz hacia arriba.
		var fc := c + Vector2(0, r * 0.42)
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, r, Color(0.2, 0.9, 1.0, 0.07))
		for i in 3:
			var rr := r * (0.55 + 0.22 * i) + 3.0 * sin(t * 2.0 + i)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 72, Color(0.3, 0.9, 1.0, 0.32 - i * 0.08), 2.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var beam := PackedVector2Array([fc + Vector2(-r * 0.7, 0), fc + Vector2(r * 0.7, 0), fc + Vector2(r * 0.45, -r * 1.1), fc + Vector2(-r * 0.45, -r * 1.1)])
		draw_colored_polygon(beam, Color(0.3, 0.9, 1.0, 0.035))
	var bob := sin(t * 1.4) * 3.0
	if pivot:
		return
	if sheet:
		var fs := float(sheet.get_width()) / COLS
		var pos: float = fposmod(angle, 360.0) / (360.0 / FRAMES)
		var i0 := int(floor(pos)) % FRAMES
		var i1 := (i0 + 1) % FRAMES
		var f: float = pos - floor(pos)
		var side := minf(size.x, size.y * 1.7) * 1.05 * zoom
		var dst := Rect2(c - Vector2(side, side) * 0.5 + Vector2(0, bob - side * 0.06), Vector2(side, side))
		# Un solo fotograma, el más cercano (fundir dos dejaba la nave en dos posiciones a la vez).
		var near := i1 if f >= 0.5 else i0
		draw_texture_rect_region(sheet, dst, Rect2((near % COLS) * fs, (near / COLS) * fs, fs, fs), Color(1, 1, 1, 1.0))
	elif flat:
		var s := r * 1.5
		draw_set_transform(c + Vector2(0, bob - r * 0.1), -PI * 0.5 + sin(t * 0.6) * 0.4, Vector2.ONE)
		draw_texture_rect(flat, Rect2(-s * 0.5, -s * 0.5, s, s), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
