"""Arte de interfaz con Stable Diffusion XL local: fondo del hangar e iconos de los misiles.

Salida: assets/backgrounds/hangar.png (1536x1024, oscuro) y assets/ui/missiles/<id>.png (256 px,
fondo transparente, en la línea de los demás iconos de objetos).

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_ui_art.py [--force]
"""
import os, sys
import torch
from diffusers import StableDiffusionXLPipeline
from PIL import Image, ImageEnhance
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEG = "text, watermark, logo, frame, border, people, person, blurry, low quality, cartoon, pixel art"
MISSILES = {
    "r1": "orange", "r2": "green", "r3": "blue", "rt4": "purple", "r5": "fiery orange and red", "r6": "golden",
}
# Descripción propia para los misiles cuyo icono genérico no se entendía (el R-3 parecía una aleta).
SHAPE = {
    "r3": ("single heavy sci-fi bunker buster missile game item icon, thick armored cylindrical body, huge blunt hammerhead warhead "
           "wider than the body, glowing blue bands, four short stubby tail fins, rear thruster nozzle, diagonal pointing up right, "
           "centered, pre-rendered 3D, gunmetal, studio lighting, isolated on black background"),
}


def main() -> None:
    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]   # ids de misil a rehacer (omite el fondo)
    torch.set_num_threads(8)
    pipe = StableDiffusionXLPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
                                                     variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()
    pipe.vae.enable_tiling()
    bg = os.path.join(ROOT, "assets", "backgrounds", "hangar.png")
    if not only and (force or not os.path.exists(bg)):
        g = torch.Generator("cpu").manual_seed(777)
        img = pipe(prompt="interior of a futuristic spaceship hangar bay, empty circular launch platform in the center, dark metal walls, blue and cyan rim lights, volumetric haze, sci-fi game menu background, wide shot, no ship",
                   negative_prompt=NEG + ", spaceship, vehicle", width=1536, height=1024, num_inference_steps=34, guidance_scale=6.5, generator=g).images[0]
        img = ImageEnhance.Brightness(img).enhance(0.55)
        img = ImageEnhance.Contrast(img).enhance(0.85)
        img.save(bg)
        print("OK hangar", flush=True)
    session = new_session("isnet-general-use")
    out_dir = os.path.join(ROOT, "assets", "ui", "missiles")
    os.makedirs(out_dir, exist_ok=True)
    # --options N: genera N variantes (build/missile_options/<id>_<n>.png) para elegir, sin tocar el icono.
    n_opt = int(sys.argv[sys.argv.index("--options") + 1]) if "--options" in sys.argv else 0
    only = [a for a in only if not a.isdigit()]
    jobs = []
    for k, (mid, col) in enumerate(MISSILES.items()):
        path = os.path.join(out_dir, f"{mid}.png")
        if only and mid not in only:
            continue
        if os.path.exists(path) and not force and not only:
            continue
        if n_opt:
            opt_dir = os.path.join(ROOT, "build", "missile_options")
            os.makedirs(opt_dir, exist_ok=True)
            jobs += [(os.path.join(opt_dir, f"{mid}_{i + 1}.png"), mid, col, 5200 + i * 131) for i in range(n_opt)]
        else:
            jobs.append((path, mid, col, 3100 + k * 41 + (997 if only else 0)))
    for path, mid, col, seed in jobs:
        g = torch.Generator("cpu").manual_seed(seed)
        prompt = SHAPE.get(mid, f"single sci-fi homing missile game item icon, sleek metallic rocket with {col} glowing stripes and tail fins, diagonal pointing up right, centered, pre-rendered 3D, studio lighting, isolated on black background")
        img = pipe(prompt=prompt, negative_prompt=NEG + ", multiple missiles, explosion, smoke, shark, fin, airplane", width=1024, height=1024,
                   num_inference_steps=30, guidance_scale=7.0, generator=g).images[0]
        cut = remove(img, session=session).convert("RGBA")
        bb = cut.getbbox()
        if bb:
            cut = cut.crop(bb)
        sc = 230 / max(cut.size)
        cut = cut.resize((max(1, int(cut.width * sc)), max(1, int(cut.height * sc))), Image.LANCZOS)
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.paste(cut, ((256 - cut.width) // 2, (256 - cut.height) // 2), cut)
        canvas.save(path)
        print("OK", os.path.basename(path), flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
