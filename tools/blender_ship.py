# Renderizado de naves en Blender a partir de los modelos de TripoSR (OBJ + texture.png).
#
#  Diagnóstico de ejes:  blender -b -P tools/blender_ship.py -- axes  <carpeta_modelo> <prefijo_salida>
#  Rotación (N vistas):  blender -b -P tools/blender_ship.py -- spin  <carpeta_modelo> <carpeta_salida> <rx> <ry> <rz> [frames] [elev]
#
# rx, ry, rz: giro en grados que deja la nave con la proa hacia +X y la parte de arriba hacia +Z.
# En "spin" la cámara es ortográfica y fija (elevación `elev`, por defecto 55°, como en DarkOrbit) y la
# nave gira sobre su eje vertical: el fotograma i tiene la proa a i*360/frames grados (antihorario visto
# desde arriba, empezando por la derecha de la pantalla).
import bpy, sys, math, os
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
mode, src = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
obj_path = os.path.join(src, "mesh.obj")
if not os.path.exists(obj_path):
    obj_path = os.path.join(src, "mesh.glb")  # TripoSR lo guarda como OBJ aunque se llame .glb
    os.replace(obj_path, os.path.join(src, "mesh.obj")); obj_path = os.path.join(src, "mesh.obj")
bpy.ops.wm.obj_import(filepath=obj_path)
ship = [o for o in scene.objects if o.type == "MESH"][0]

# Material con la textura horneada
tex_path = os.path.join(src, "texture.png")
mat = bpy.data.materials.new("ship"); mat.use_nodes = True
nodes = mat.node_tree.nodes; bsdf = nodes.get("Principled BSDF")
if os.path.exists(tex_path):
    img = nodes.new("ShaderNodeTexImage"); img.image = bpy.data.images.load(tex_path)
    mat.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.45
bsdf.inputs["Metallic"].default_value = 0.35
ship.data.materials.clear(); ship.data.materials.append(mat)
bpy.context.view_layer.objects.active = ship
bpy.ops.object.shade_smooth()



def polish():
    """Material pulido: superficie lisa con barniz brillante, colores más saturados y emisión en las
    zonas de color vivo (ventanas, luces, detalles), para naves que deben verse impecables."""
    nt = mat.node_tree
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
    if tex is None:
        return
    bsdf.inputs["Roughness"].default_value = 0.12
    bsdf.inputs["Metallic"].default_value = 0.55
    for name in ("Coat Weight", "Clearcoat"):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = 1.0
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = 0.05
    sat = nt.nodes.new("ShaderNodeHueSaturation"); sat.inputs["Saturation"].default_value = 1.3
    nt.links.new(tex.outputs["Color"], sat.inputs["Color"])
    nt.links.new(sat.outputs["Color"], bsdf.inputs["Base Color"])
    # Emisión donde el color es vivo y luminoso (saturación x valor alto).
    hsv = nt.nodes.new("ShaderNodeSeparateColor"); hsv.mode = "HSV"
    nt.links.new(tex.outputs["Color"], hsv.inputs["Color"])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt.links.new(hsv.outputs[1], mul.inputs[0]); nt.links.new(hsv.outputs[2], mul.inputs[1])
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = 0.30; rng.inputs["From Max"].default_value = 0.65
    rng.inputs["To Min"].default_value = 0.0; rng.inputs["To Max"].default_value = 4.0
    nt.links.new(mul.outputs[0], rng.inputs["Value"])
    ec = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
    nt.links.new(sat.outputs["Color"], bsdf.inputs[ec])
    nt.links.new(rng.outputs["Result"], bsdf.inputs["Emission Strength"])


def normalize():
    # Centra la malla en el origen y la escala a 2 unidades midiendo los vértices reales
    # (bound_box puede quedar desactualizado tras editar la malla).
    from mathutils import Matrix
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in ship.data.vertices]
    mn = Vector([min(v[i] for v in vs) for i in range(3)]); mx = Vector([max(v[i] for v in vs) for i in range(3)])
    s = 2.0 / max(mx - mn)
    ship.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-(mn + mx) / 2))
    ship.data.update()
    bpy.context.view_layer.update()


def _bounds():
    bpy.context.view_layer.update()
    vs = [ship.matrix_world @ v.co for v in ship.data.vertices]
    mn = Vector([min(v[i] for v in vs) for i in range(3)]); mx = Vector([max(v[i] for v in vs) for i in range(3)])
    return mn, mx, vs


def refine(thickness: float = 0.32, min_part: float = 0.03, smooth_iter: int = 6):
    """Limpia un modelo de TripoSR ya orientado (proa +X, arriba +Z):
    quita piezas sueltas pequeñas, suaviza las abolladuras, recorta lo que cuelga por debajo de un
    grosor razonable (fracción de la mayor dimensión en planta) y lo hace simétrico de izquierda a derecha
    quedándose con la mitad más limpia."""
    global ship
    bpy.ops.object.select_all(action="DESELECT")
    ship.select_set(True); bpy.context.view_layer.objects.active = ship
    # 1. Piezas sueltas: se separan y se borran las que tienen menos de min_part de los vértices.
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    # Une los vértices duplicados en las costuras de la textura (si no, cada isla UV parece una pieza suelta).
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in scene.objects if o.type == "MESH"]
    total = sum(len(o.data.vertices) for o in parts)
    keep = [o for o in parts if len(o.data.vertices) >= total * min_part] or [max(parts, key=lambda o: len(o.data.vertices))]
    for o in parts:
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in keep:
        o.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    if len(keep) > 1:
        bpy.ops.object.join()
    ship = bpy.context.view_layer.objects.active
    # 2. Suavizado de las abolladuras (conserva la forma general).
    sm = ship.modifiers.new("suave", "SMOOTH"); sm.factor = 0.5; sm.iterations = smooth_iter
    bpy.ops.object.modifier_apply(modifier=sm.name)
    # 3. Grosor: todo lo que queda por debajo de (techo - grosor) se recorta y el corte se cierra.
    mn, mx, vs = _bounds()
    plan = max(mx.x - mn.x, mx.y - mn.y)
    z_cut = mx.z - thickness * plan
    if z_cut > mn.z:
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.bisect(plane_co=(0, 0, z_cut), plane_no=(0, 0, 1), clear_inner=True, use_fill=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    # 4. Simetría izquierda/derecha: eje en el centro de la planta; se conserva la mitad que menos cuelga.
    mn, mx, vs = _bounds()
    cy = (mn.y + mx.y) / 2
    pos = [v.z for v in vs if v.y > cy]; neg = [v.z for v in vs if v.y < cy]
    keep_pos = (min(pos) if pos else 0) >= (min(neg) if neg else 0)
    ship.location.y -= cy
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(plane_co=(0, 0, 0), plane_no=(0, 1, 0), clear_inner=keep_pos, clear_outer=not keep_pos)
    bpy.ops.object.mode_set(mode="OBJECT")
    mi = ship.modifiers.new("simetria", "MIRROR"); mi.use_axis = (False, True, False)
    mi.use_mirror_merge = True; mi.merge_threshold = 0.004
    bpy.ops.object.modifier_apply(modifier=mi.name)
    bpy.ops.object.shade_smooth()

scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 384   # se reduce a 192 al empaquetar: más nitidez
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w"); scene.world = world; world.color = (0.55, 0.57, 0.62)
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 2.6
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
# Luz principal desde arriba-izquierda (como el resto del arte) y relleno suave.
key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN")); scene.collection.objects.link(key)
key.data.energy = 5.5; key.rotation_euler = Euler((math.radians(35), 0, math.radians(-135)))
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN")); scene.collection.objects.link(fill)
fill.data.energy = 2.0; fill.rotation_euler = Euler((math.radians(60), 0, math.radians(60)))
# Luz de contorno desde detrás de la nave (hacia la cámara): recorta la silueta y marca los volúmenes.
rim = bpy.data.objects.new("rim", bpy.data.lights.new("rim", "SUN")); scene.collection.objects.link(rim)
rim.data.energy = 2.5; rim.rotation_euler = Euler((math.radians(-70), 0, 0))

def look_from(direction: Vector, dist: float = 6.0):
    cam.location = direction.normalized() * dist
    up_axis = "Y" if abs(direction.normalized().z) > 0.99 else "Z"
    cam.rotation_euler = (-direction).to_track_quat("-Z", up_axis).to_euler()

if mode == "axes":
    out = argv[2]
    normalize()
    for name, d in {"px": (1, 0, 0), "nx": (-1, 0, 0), "py": (0, 1, 0), "ny": (0, -1, 0), "pz": (0, 0, 1), "nz": (0, 0, -1)}.items():
        look_from(Vector(d))
        scene.render.filepath = f"{out}_{name}.png"
        bpy.ops.render.render(write_still=True)
elif mode == "spin":
    out = argv[2]
    rx, ry, rz = (math.radians(float(a)) for a in argv[3:6])
    frames = int(argv[6]) if len(argv) > 6 else 32
    elev = math.radians(float(argv[7])) if len(argv) > 7 else math.radians(55)
    ship.rotation_mode = "XYZ"
    ship.rotation_euler = Euler((rx, ry, rz))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    profile = argv[8].split("+") if len(argv) > 8 else ["refine"]
    if "polish" in profile:
        polish()
    if "soft" in profile:
        refine(thickness=0.7, smooth_iter=10)  # orgánicos: sin recortar el cuerpo
    elif "smooth" in profile:
        refine(smooth_iter=14)  # superficie extra lisa
    elif "raw" not in profile:
        refine()  # simetría, sin piezas sueltas ni partes colgando, superficie suavizada
    normalize()
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    # Cámara fija mirando desde el sur de la pantalla (-Y), elevada `elev`.
    look_from(Vector((0, -math.cos(elev), math.sin(elev))))
    os.makedirs(out, exist_ok=True)
    for i in range(frames):
        ship.rotation_euler = Euler((0, 0, 2 * math.pi * i / frames))
        scene.render.filepath = os.path.join(out, f"{i:02d}.png")
        bpy.ops.render.render(write_still=True)
elif mode == "inspect":
    # Orientación de juego (proa +X, arriba +Z) y 4 vistas: arriba, abajo, lado y frente.
    out = argv[2]
    rx, ry, rz = (math.radians(float(a)) for a in argv[3:6])
    ship.rotation_mode = "XYZ"
    ship.rotation_euler = Euler((rx, ry, rz))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    if len(argv) > 6 and argv[6] == "refine":
        refine()
    normalize()
    for name, d in {"arriba": (0, 0, 1), "abajo": (0, 0, -1), "lado": (0, -1, 0), "frente": (1, 0, 0)}.items():
        look_from(Vector(d))
        scene.render.filepath = f"{out}_{name}.png"
        bpy.ops.render.render(write_still=True)
