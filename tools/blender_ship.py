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

def normalize():
    # Centra el modelo en el origen y lo escala a un tamaño de 2 unidades.
    bpy.context.view_layer.update()
    ws = [ship.matrix_world @ Vector(v) for v in ship.bound_box]
    mn = Vector([min(w[i] for w in ws) for i in range(3)]); mx = Vector([max(w[i] for w in ws) for i in range(3)])
    ship.location -= (mn + mx) / 2
    s = 2.0 / max(mx - mn)
    ship.scale *= s
    bpy.context.view_layer.update()

scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w"); scene.world = world; world.color = (0.55, 0.57, 0.62)
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 2.6
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
# Luz principal desde arriba-izquierda (como el resto del arte) y relleno suave.
key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN")); scene.collection.objects.link(key)
key.data.energy = 5.5; key.rotation_euler = Euler((math.radians(35), 0, math.radians(-135)))
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN")); scene.collection.objects.link(fill)
fill.data.energy = 2.0; fill.rotation_euler = Euler((math.radians(60), 0, math.radians(60)))

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
    normalize()
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    # Cámara fija mirando desde el sur de la pantalla (-Y), elevada `elev`.
    look_from(Vector((0, -math.cos(elev), math.sin(elev))))
    os.makedirs(out, exist_ok=True)
    for i in range(frames):
        ship.rotation_euler = Euler((0, 0, 2 * math.pi * i / frames))
        scene.render.filepath = os.path.join(out, f"{i:02d}.png")
        bpy.ops.render.render(write_still=True)
