"""Genera propuestas de sprites de nave con Stable Diffusion XL en local (GPU) y les quita el fondo.

Uso (entorno D:\\Proyectos\\herramientas\\triposr_env):
    python tools/sdxl_ships.py [ids...] [--n 4] [--steps 32]

Cada propuesta se guarda en build/redesign/<id>_<n>.png (1024x1024, fondo transparente, vista desde
arriba con la proa a la derecha) y una hoja de contacto en build/redesign/hoja.png.
"""
import argparse, os, sys
import torch
from diffusers import StableDiffusionXLPipeline
from PIL import Image, ImageDraw
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "redesign")

# Ojo: SDXL sólo lee ~77 tokens: la nave va primero y el estilo, corto, después.
STYLE = (
    "top-down view from directly above, sci-fi spaceship game sprite, pre-rendered 3D, "
    "nose pointing up, symmetric, studio lighting, isolated on black background"
)
NEGATIVE = (
    "pixel art, cartoon, drawing, text, watermark, frame, perspective, side view, planet, stars, "
    "multiple ships, cropped, blurry, deformed, asymmetric, silver, chrome"
)
SHIPS = {
    "bulwark_t1": "olive green military armored tank spaceship, wide hexagonal hull, heavy olive green armor plates, "
                  "pointed armored prow, two twin-cannon turrets, four orange glowing engines",
    "mammoth_k": "huge rust red and black armored fortress spaceship, battering ram prow, rust red armor plates "
                 "with yellow hazard stripes, many turrets, six orange glowing engines",
    "mule_c1": "yellow industrial cargo spaceship, bright yellow cockpit at the front, long spine carrying "
               "stacked orange and grey cargo containers, two cyan glowing engines",
}


def fit(img: Image.Image) -> Image.Image:
    """Recorta al contenido y lo centra ocupando ~80% de un lienzo de 1024."""
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    side = max(img.size)
    scale = 820 / side
    img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.paste(img, ((1024 - img.width) // 2, (1024 - img.height) // 2), img)
    return canvas


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*", default=list(SHIPS))
    ap.add_argument("--n", type=int, default=4)
    ap.add_argument("--steps", type=int, default=32)
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    pipe = StableDiffusionXLPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()  # cabe en 8 GB de VRAM
    torch.set_num_threads(8)  # ~40% de la CPU: el PC sigue usable
    session = new_session("isnet-general-use")
    results = []
    for sid in args.ids:
        for k in range(args.n):
            g = torch.Generator("cpu").manual_seed(1000 + k * 77 + list(SHIPS).index(sid) * 1009)
            img = pipe(prompt=f"{SHIPS[sid]}, {STYLE}", negative_prompt=NEGATIVE, width=1024, height=1024,
                       num_inference_steps=args.steps, guidance_scale=7.0, generator=g).images[0]
            # Fondo fuera (isnet: mejor para objetos) y giro de 90° horario: la proa pasa de arriba a la derecha.
            out = fit(remove(img, session=session).convert("RGBA").rotate(-90, expand=True))
            path = os.path.join(OUT, f"{sid}_{k + 1}.png")
            out.save(path)
            results.append((sid, k + 1, out))
            print(f"OK {sid}_{k + 1}", flush=True)
    # Hoja de contacto
    cols = args.n
    sheet = Image.new("RGB", (cols * 300, len(args.ids) * 330), (20, 24, 36))
    d = ImageDraw.Draw(sheet)
    for idx, (sid, k, im) in enumerate(results):
        r, c = idx // cols, idx % cols
        thumb = im.resize((280, 280), Image.LANCZOS)
        sheet.paste(thumb, (c * 300 + 10, r * 330 + 34), thumb)
        d.text((c * 300 + 12, r * 330 + 8), f"{sid}  opcion {k}", fill=(255, 210, 80))
    sheet.save(os.path.join(OUT, "hoja.png"))
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
