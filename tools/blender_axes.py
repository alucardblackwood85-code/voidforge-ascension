# Diagnóstico de orientación: renderiza un modelo GLB desde los 6 ejes (+X, -X, +Y, -Y, +Z, -Z).
# Uso: blender -b -P tools/blender_axes.py -- modelo.glb salida_prefijo
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# Centrar y normalizar a tamaño 2
mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
for o in objs:
    for v in o.bound_box:
        w = o.matrix_world @ Vector(v)
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
center = (mn + mx) / 2; size = max(mx - mn)
for o in objs:
    o.location -= center
bpy.ops.object.select_all(action="DESELECT")
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 256
world = bpy.data.worlds.new("w"); scene.world = world
world.color = (0.5, 0.5, 0.5)
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = size * 1.2
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scene.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(40), math.radians(20), 0)
dirs = {"px": Vector((1, 0, 0)), "nx": Vector((-1, 0, 0)), "py": Vector((0, 1, 0)), "ny": Vector((0, -1, 0)), "pz": Vector((0, 0, 1)), "nz": Vector((0, 0, -1))}
for name, d in dirs.items():
    cam.location = d * size * 3
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, 1, 0))
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y" if abs(d.z) > 0.9 else "Z").to_euler()
    scene.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
