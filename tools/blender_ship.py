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
glb_path = os.path.join(src, "model.glb")   # modelos de Tripo (API): GLB con o sin materiales PBR
keep_mat = False
if os.path.exists(glb_path):
    bpy.ops.import_scene.gltf(filepath=glb_path)
    meshes = [o for o in scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    for o in [o for o in scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    ship = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Perfil «tex»: se conservan los materiales PBR de Tripo en vez de proyectar el sprite.
    keep_mat = len(argv) > 8 and "tex" in argv[8].split("+")
else:
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
if not keep_mat:
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


def refine(thickness: float = 0.32, min_part: float = 0.03, smooth_iter: int = 6, mirror: bool = True):
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
    if not mirror:
        bpy.ops.object.shade_smooth()
        return
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

def metalize(voxel: float = 0.014, smooth_iter: int = 30, ratio: float = 0.1, tex_res: int = 1024, colors: int = 10):
    """Pulido de superficie dura para los modelos «de plastilina» de TripoSR:
    1) remallado por vóxeles + alisado laplaciano que conserva el volumen (adiós arrugas),
    2) simplificación a caras planas (paneles) y sombreado por ángulo (aristas nítidas),
    3) los colores del modelo original se hornean en la malla nueva (Cycles) y se reducen a una paleta
       limpia de pocos tonos con un leve desenfoque (se van las arrugas «pintadas» en la textura),
    4) material metálico con barniz y un entorno en degradado que da reflejos."""
    global ship, mat, bsdf
    import numpy as np
    hi = ship
    lo = hi.copy(); lo.data = hi.data.copy(); scene.collection.objects.link(lo)
    lo.data.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    lo.select_set(True); bpy.context.view_layer.objects.active = lo
    rm = lo.modifiers.new("remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=rm.name)
    ls = lo.modifiers.new("lap", "LAPLACIANSMOOTH"); ls.lambda_factor = 0.9; ls.iterations = smooth_iter
    ls.use_volume_preserve = True; ls.use_normalized = True
    bpy.ops.object.modifier_apply(modifier=ls.name)
    dc = lo.modifiers.new("dec", "DECIMATE"); dc.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=dc.name)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Horneado del color del original sobre la malla nueva.
    img = bpy.data.images.new("bake", tex_res, tex_res)
    m2 = bpy.data.materials.new("metal"); m2.use_nodes = True
    n2 = m2.node_tree.nodes; b2 = n2.get("Principled BSDF")
    tn = n2.new("ShaderNodeTexImage"); tn.image = img; n2.active = tn
    lo.data.materials.append(m2)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    try:
        bpy.context.preferences.addons["cycles"].preferences.compute_device_type = "CUDA"
        bpy.context.preferences.addons["cycles"].preferences.get_devices()
        scene.cycles.device = "GPU"
    except Exception:
        pass
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.12, margin=6)
    # Paleta limpia: k-medias sobre los colores horneados y desenfoque suave.
    px = np.array(img.pixels[:], dtype=np.float32).reshape(tex_res, tex_res, 4)
    rgb = px[:, :, :3]
    valid = px[:, :, 3] > 0.5
    sample = rgb[valid][:: max(1, int(valid.sum() / 20000))]
    if len(sample) > colors:
        rng = np.random.default_rng(1)
        cent = sample[rng.choice(len(sample), colors, replace=False)]
        for _ in range(12):
            lab = np.argmin(((sample[:, None, :] - cent[None, :, :]) ** 2).sum(-1), axis=1)
            for k in range(colors):
                if (lab == k).any():
                    cent[k] = sample[lab == k].mean(0)
        flat = rgb.reshape(-1, 3)
        lab = np.empty(len(flat), dtype=np.int32)
        for i0 in range(0, len(flat), 262144):
            lab[i0:i0 + 262144] = np.argmin(((flat[i0:i0 + 262144, None, :] - cent[None, :, :]) ** 2).sum(-1), axis=1)
        q = cent[lab].reshape(rgb.shape)
        # Mezcla 75% paleta / 25% original suavizado: conserva algo de matiz sin las arrugas.
        k5 = np.ones(5) / 5.0
        sm = rgb.copy()
        for ax in (0, 1):
            sm = np.apply_along_axis(lambda m: np.convolve(m, k5, mode="same"), ax, sm)
        rgb = q * 0.6 + sm * 0.4
        px[:, :, :3] = rgb
        img.pixels[:] = px.ravel()
    img.pack()
    bpy.data.objects.remove(hi, do_unlink=True)
    ship = lo; mat = m2; bsdf = b2
    nt2 = m2.node_tree
    sat = nt2.nodes.new("ShaderNodeHueSaturation"); sat.inputs["Saturation"].default_value = 1.35
    nt2.links.new(tn.outputs["Color"], sat.inputs["Color"])
    nt2.links.new(sat.outputs["Color"], b2.inputs["Base Color"])
    b2.inputs["Metallic"].default_value = 0.6
    b2.inputs["Roughness"].default_value = 0.38
    # Brillo propio en los colores vivos (cabinas, luces, franjas), como en el perfil «polish».
    hsv = nt2.nodes.new("ShaderNodeSeparateColor"); hsv.mode = "HSV"
    nt2.links.new(tn.outputs["Color"], hsv.inputs["Color"])
    mul = nt2.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt2.links.new(hsv.outputs[1], mul.inputs[0]); nt2.links.new(hsv.outputs[2], mul.inputs[1])
    mr = nt2.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.22; mr.inputs["From Max"].default_value = 0.55
    mr.inputs["To Min"].default_value = 0.0; mr.inputs["To Max"].default_value = 2.5
    nt2.links.new(mul.outputs[0], mr.inputs["Value"])
    ec = "Emission Color" if "Emission Color" in b2.inputs else "Emission"
    nt2.links.new(sat.outputs["Color"], b2.inputs[ec])
    nt2.links.new(mr.outputs["Result"], b2.inputs["Emission Strength"])
    for name in ("Coat Weight", "Clearcoat"):
        if name in b2.inputs:
            b2.inputs[name].default_value = 0.6
    if "Coat Roughness" in b2.inputs:
        b2.inputs["Coat Roughness"].default_value = 0.08
    bpy.context.view_layer.objects.active = ship
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(32))
    except Exception:
        bpy.ops.object.shade_flat()
    scene.render.engine = "BLENDER_EEVEE"
    # Entorno en degradado (suelo oscuro, horizonte claro, cielo azulado): reflejos para el metal.
    w = scene.world; w.use_nodes = True
    wn = w.node_tree.nodes; wl = w.node_tree.links
    for n in list(wn):
        if n.type != "OUTPUT_WORLD":
            wn.remove(n)
    tc = wn.new("ShaderNodeTexCoord"); sx = wn.new("ShaderNodeSeparateXYZ"); cr = wn.new("ShaderNodeValToRGB")
    bg = wn.new("ShaderNodeBackground"); bg.inputs["Strength"].default_value = 1.0
    wl.new(tc.outputs["Generated"], sx.inputs[0]); wl.new(sx.outputs["Z"], cr.inputs["Fac"])
    cr.color_ramp.elements[0].position = 0.35; cr.color_ramp.elements[0].color = (0.04, 0.05, 0.07, 1)
    cr.color_ramp.elements[1].position = 0.75; cr.color_ramp.elements[1].color = (0.55, 0.65, 0.8, 1)
    mid = cr.color_ramp.elements.new(0.52); mid.color = (1.0, 0.97, 0.92, 1)
    wl.new(cr.outputs["Color"], bg.inputs["Color"])
    out = next(n for n in wn if n.type == "OUTPUT_WORLD")
    wl.new(bg.outputs["Background"], out.inputs["Surface"])


def env_reflections():
    """Entorno en degradado (suelo oscuro, horizonte claro, cielo azulado): reflejos para el metal."""
    w = scene.world; w.use_nodes = True
    wn = w.node_tree.nodes; wl = w.node_tree.links
    for n in list(wn):
        if n.type != "OUTPUT_WORLD":
            wn.remove(n)
    tc = wn.new("ShaderNodeTexCoord"); sx = wn.new("ShaderNodeSeparateXYZ"); cr = wn.new("ShaderNodeValToRGB")
    bg = wn.new("ShaderNodeBackground"); bg.inputs["Strength"].default_value = 1.0
    wl.new(tc.outputs["Generated"], sx.inputs[0]); wl.new(sx.outputs["Z"], cr.inputs["Fac"])
    cr.color_ramp.elements[0].position = 0.35; cr.color_ramp.elements[0].color = (0.04, 0.05, 0.07, 1)
    cr.color_ramp.elements[1].position = 0.75; cr.color_ramp.elements[1].color = (0.55, 0.65, 0.8, 1)
    mid = cr.color_ramp.elements.new(0.52); mid.color = (1.0, 0.97, 0.92, 1)
    wl.new(cr.outputs["Color"], bg.inputs["Color"])
    out = next(n for n in wn if n.type == "OUTPUT_WORLD")
    wl.new(bg.outputs["Background"], out.inputs["Surface"])


def hy3d_material():
    """Modelos de Hunyuan3D (geometría limpia, sin textura): el sprite original se proyecta desde arriba
    sobre la nave ya orientada (proa +X, arriba +Z), ajustando su silueta (caja del alfa) a la de la malla.
    Material metálico con barniz, colores algo más vivos y brillo propio en cabinas y luces."""
    global mat, bsdf
    import numpy as np
    timg = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
    if timg is None:
        return
    w, h = timg.size
    px = np.array(timg.pixels[:], dtype=np.float32).reshape(h, w, 4)   # fila 0 = abajo de la imagen
    ys, xs = np.nonzero(px[:, :, 3] > 0.1)
    u0, u1 = xs.min() / w, (xs.max() + 1) / w
    v0, v1 = ys.min() / h, (ys.max() + 1) / h
    # Las caras casi verticales (laterales, cúpulas, esferas) caen en el borde de la silueta o fuera de
    # ella, donde el sprite es transparente (negro): se extienden los colores del sprite hacia fuera.
    rgb = px[:, :, :3].copy()
    known = px[:, :, 3] > 0.5
    for _ in range(96):
        if known.all():
            break
        acc = np.zeros_like(rgb); cnt = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * k[..., None]; cnt += k
        new = (~known) & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]; known |= new
    px[:, :, :3] = rgb
    timg.pixels[:] = px.ravel()
    timg.alpha_mode = "CHANNEL_PACKED"   # el color no se multiplica por el alfa
    me = ship.data
    vs = [v.co for v in me.vertices]
    mnx = min(v.x for v in vs); mxx = max(v.x for v in vs); mny = min(v.y for v in vs); mxy = max(v.y for v in vs)
    uv = me.uv_layers.new(name="top") if not me.uv_layers else me.uv_layers[0]
    me.uv_layers.active = uv
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        fu = (co.x - mnx) / max(1e-6, mxx - mnx)
        fv = (co.y - mny) / max(1e-6, mxy - mny)
        uv.data[loop.index].uv = (u0 + fu * (u1 - u0), v0 + fv * (v1 - v0))
    nt = mat.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    tex.extension = "EXTEND"
    sat = nt.nodes.new("ShaderNodeHueSaturation"); sat.inputs["Saturation"].default_value = 1.2
    nt.links.new(tex.outputs["Color"], sat.inputs["Color"])
    nt.links.new(sat.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.55
    bsdf.inputs["Roughness"].default_value = 0.33
    for name in ("Coat Weight", "Clearcoat"):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = 0.5
    hsv = nt.nodes.new("ShaderNodeSeparateColor"); hsv.mode = "HSV"
    nt.links.new(tex.outputs["Color"], hsv.inputs["Color"])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt.links.new(hsv.outputs[1], mul.inputs[0]); nt.links.new(hsv.outputs[2], mul.inputs[1])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.3; mr.inputs["From Max"].default_value = 0.6
    mr.inputs["To Min"].default_value = 0.0; mr.inputs["To Max"].default_value = 2.0
    nt.links.new(mul.outputs[0], mr.inputs["Value"])
    ec = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
    nt.links.new(sat.outputs["Color"], bsdf.inputs[ec])
    nt.links.new(mr.outputs["Result"], bsdf.inputs["Emission Strength"])
    bpy.context.view_layer.objects.active = ship
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30))
    except Exception:
        pass
    env_reflections()


def export_hangar_glb(path: str, faces: int = 15000, tex_size: int = 512):
    """Modelo para el hangar en 3D en tiempo real (Godot): la nave ya orientada (proa +X, arriba +Z) y con la
    proyección del sprite del perfil hy3d, reducida a `faces` caras y con un material exportable a glTF:
    color (sprite con +20% de saturación) y emisión (cabinas y luces, como el perfil hy3d) en texturas de
    `tex_size` px, metal 0,55, rugosidad 0,33 y barniz 0,5."""
    import numpy as np
    timg = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
    if timg is None:
        raise SystemExit("export_hangar_glb: falta la textura del sprite")
    w, h = timg.size
    px = np.array(timg.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[:, :, :3]
    gray = (rgb * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2, keepdims=True)
    col = np.clip(gray + (rgb - gray) * 1.2, 0.0, 1.0)
    mx = col.max(axis=2); mn = col.min(axis=2)
    sat = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    glow = np.clip((sat * mx - 0.3) / 0.3, 0.0, 1.0)          # mismo umbral que hy3d_material (0,3-0,6)

    def make_img(name, arr):
        im = bpy.data.images.new(name, w, h, alpha=False)
        full = np.concatenate([arr, np.ones((h, w, 1), dtype=np.float32)], axis=2)
        im.pixels[:] = full.ravel()
        im.scale(tex_size, tex_size)
        im.pack()
        return im
    albedo = make_img("albedo", col)
    emissive = make_img("emissive", col * glow[..., None])
    m2 = bpy.data.materials.new("hangar"); m2.use_nodes = True
    nt = m2.node_tree; b = nt.nodes.get("Principled BSDF")
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = albedo; ta.extension = "EXTEND"
    te = nt.nodes.new("ShaderNodeTexImage"); te.image = emissive; te.extension = "EXTEND"
    nt.links.new(ta.outputs["Color"], b.inputs["Base Color"])
    ec = "Emission Color" if "Emission Color" in b.inputs else "Emission"
    nt.links.new(te.outputs["Color"], b.inputs[ec])
    b.inputs["Emission Strength"].default_value = 2.0
    b.inputs["Metallic"].default_value = 0.55
    b.inputs["Roughness"].default_value = 0.33
    for name in ("Coat Weight", "Clearcoat"):
        if name in b.inputs:
            b.inputs[name].default_value = 0.5
    ship.data.materials.clear(); ship.data.materials.append(m2)
    bpy.context.view_layer.objects.active = ship
    n_faces = len(ship.data.polygons)
    if n_faces > faces:
        dec = ship.modifiers.new("dec", "DECIMATE"); dec.ratio = faces / n_faces
        bpy.ops.object.modifier_apply(modifier="dec")
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30))
    except Exception:
        pass
    bpy.ops.object.select_all(action="DESELECT"); ship.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=85, export_cameras=False, export_lights=False)
    print("GLB", path, len(ship.data.polygons), "caras")


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
    rot_deg = [float(a) for a in argv[3:6]]
    # Correcciones por nave de los modelos de Hunyuan3D (tools/hy3d_fix.json).
    fix = {}
    if len(argv) > 8 and ("hy3d" in argv[8] or "tex" in argv[8]):
        import json
        # Modelos de Tripo (GLB): orientación de tools/tripo_orient.py; los de TripoSG/Hunyuan, hy3d_fix.json.
        fname = "tripo_fix.json" if os.path.exists(glb_path) else "hy3d_fix.json"
        fpath = os.path.join(os.path.dirname(os.path.abspath(__file__)), fname)
        if os.path.exists(fpath):
            fix = json.load(open(fpath, encoding="utf-8")).get(os.path.basename(os.path.normpath(src)), {})
        for i, k in enumerate(("rx", "ry", "rz")):
            if k in fix:
                rot_deg[i] = float(fix[k])
    rx, ry, rz = (math.radians(a) for a in rot_deg)
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
    elif "raw" not in profile and "hy3d" not in profile:
        refine(mirror="nomirror" not in profile)  # simetría, sin piezas sueltas ni partes colgando, superficie suavizada
    if "metal" in profile:
        normalize()
        metalize()  # superficie dura metálica sin arrugas
    if "hy3d" in profile:
        normalize()
        if "cut" in fix:
            # Quita la copia en espejo de debajo: corta a esa altura, conserva lo de arriba y cierra la base.
            mn, mx, vs = _bounds()
            zc = mn.z + float(fix["cut"]) * (mx.z - mn.z)
            bpy.context.view_layer.objects.active = ship
            bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.bisect(plane_co=(0, 0, zc), plane_no=(0, 0, 1), clear_inner=True, use_fill=True)
            bpy.ops.object.mode_set(mode="OBJECT")
            normalize()
        if "flat" in fix:
            ship.scale.z = float(fix["flat"])
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            normalize()
        hy3d_material()  # modelo de Hunyuan3D: sprite proyectado desde arriba + metal
    if "tex" in profile:
        normalize()
        env_reflections()  # materiales PBR propios de Tripo: sólo el entorno para los reflejos
    normalize()
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    glb_out = next((a[4:] for a in argv if a.startswith("glb=")), "")
    if glb_out:
        export_hangar_glb(glb_out, int(next((a[6:] for a in argv if a.startswith("faces=")), "15000")))
        sys.exit(0)
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
