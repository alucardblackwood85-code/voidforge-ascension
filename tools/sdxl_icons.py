"""Mejora los iconos de la interfaz con Stable Diffusion XL (imagen a imagen) sin rediseñarlos de cero.

Parte de cada icono actual (assets/ui/<grupo>/<id>.png), lo amplía a 1024 px y lo refina con una
intensidad moderada: conserva forma, color e identidad, y gana acabado de render 3D (metal, oclusión
ambiental, luz de estudio) a juego con los modelos de las naves. Quita el fondo y guarda a 256 px en
build/icons_new/<grupo>/<id>.png (el doble de resolución que los actuales), más una comparativa por grupo.

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_icons.py [grupos...] [--strength 0.45] [--only grupo/id]
"""
import argparse, os, glob
import torch
from diffusers import StableDiffusionXLImg2ImgPipeline
from PIL import Image, ImageDraw
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "ui")
OUT = os.path.join(ROOT, "build", "icons_new")

# El objeto va primero (SDXL sólo lee ~77 tokens).
GROUPS = {
    "lasers": "sci-fi laser cannon weapon module",
    "drone_lasers": "small sci-fi drone laser turret module",
    "gens": "sci-fi energy generator device module",
    "ammo": "sci-fi energy ammunition canister cell",
    "mats": "raw mineral ore chunk, natural crystal resource",
    "items": "sci-fi consumable gadget device",
    "boxes": "sci-fi supply crate container",
    "mods": "sci-fi hexagonal upgrade module chip",
}
STYLE = ("game item icon, pre-rendered 3D, realistic metal and materials, ambient occlusion, "
         "soft studio lighting from the top-left, subtle emissive glow, centered, isolated on dark background, highly detailed")
NEGATIVE = "pixel art, cartoon, flat, drawing, text, watermark, frame, border, background scene, multiple objects, blurry, low quality"


def fit(img: Image.Image, size: int = 256, fill: float = 0.88) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    scale = size * fill / max(img.size)
    img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img)
    return canvas


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("groups", nargs="*", default=list(GROUPS))
    ap.add_argument("--strength", type=float, default=0.45)
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()
    torch.set_num_threads(8)
    session = new_session("isnet-general-use")
    for grp in args.groups:
        files = sorted(glob.glob(os.path.join(SRC, grp, "*.png")))
        os.makedirs(os.path.join(OUT, grp), exist_ok=True)
        pairs = []
        for path in files:
            iid = os.path.splitext(os.path.basename(path))[0]
            if args.only and args.only != f"{grp}/{iid}":
                continue
            old = Image.open(path).convert("RGBA")
            base = Image.new("RGBA", old.size, (16, 20, 30, 255))
            base.alpha_composite(old)
            init = base.convert("RGB").resize((1024, 1024), Image.LANCZOS)
            name = iid.replace("_", " ")
            g = torch.Generator("cpu").manual_seed(abs(hash(f"{grp}/{iid}")) % 100000)
            img = pipe(prompt=f"{GROUPS[grp]} ({name}), {STYLE}", negative_prompt=NEGATIVE, image=init,
                       strength=args.strength, num_inference_steps=args.steps, guidance_scale=6.0, generator=g).images[0]
            new = fit(remove(img, session=session).convert("RGBA"))
            new.save(os.path.join(OUT, grp, f"{iid}.png"))
            pairs.append((iid, old, new))
            print(f"OK {grp}/{iid}", flush=True)
        # Comparativa del grupo: arriba el icono actual, abajo el nuevo.
        if pairs:
            cols = min(8, len(pairs))
            rows = (len(pairs) + cols - 1) // cols
            sheet = Image.new("RGB", (cols * 170, rows * 380), (20, 24, 36))
            d = ImageDraw.Draw(sheet)
            for i, (iid, old, new) in enumerate(pairs):
                x, y = (i % cols) * 170, (i // cols) * 380
                d.text((x + 6, y + 4), iid, fill=(255, 210, 80))
                o = old.resize((150, 150), Image.LANCZOS); sheet.paste(o, (x + 10, y + 20), o)
                n = new.resize((150, 150), Image.LANCZOS); sheet.paste(n, (x + 10, y + 200), n)
                d.text((x + 6, y + 172), "actual", fill=(160, 160, 170))
                d.text((x + 6, y + 352), "nuevo", fill=(120, 220, 140))
            sheet.save(os.path.join(OUT, f"comparativa_{grp}.png"))
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
