"""Limpia las vistas en tres cuartos de las naves con SDXL (img2img suave) antes de TripoSG.

Las vistas salen de los modelos antiguos de TripoSR (superficie «de plastilina»). Un img2img con poca
fuerza las convierte en un render de superficie dura (paneles de metal y aristas nítidas) manteniendo la
forma, colores y orientación, y así TripoSG genera geometría limpia. Licencias: SDXL (OpenRAIL++) y
TripoSG (MIT), sin restricciones territoriales.
Entrada: build/tsg_in/<id>/05.png  ·  Salida: build/tsg_in/<id>/clean.png

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_clean_views.py [ids...] [--strength 0.42] [--out clean.png] [--seed 77]
"""
import os, sys
import torch
from diffusers import StableDiffusionXLImg2ImgPipeline
from PIL import Image
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROMPT = ("hard surface sci-fi spaceship, fully enclosed pressurized cockpit with a smooth dark tinted glass canopy, "
          "sealed hull, clean smooth metal armor panels, sharp crisp edges, panel lines, "
          "high quality 3d render, studio lighting, plain grey background")
NEG = ("wrinkles, lumpy, melted, clay, organic, blurry, noisy, deformed, low quality, text, watermark, "
       "open cockpit, exposed seat, pilot seat, pilot, person, open roof, holes")


def main() -> None:
    strength = float(sys.argv[sys.argv.index("--strength") + 1]) if "--strength" in sys.argv else 0.42
    out_name = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "clean.png"
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 77
    ids = [a for i, a in enumerate(sys.argv[1:], 1) if not a.startswith("--") and sys.argv[i - 1] not in ("--strength", "--out", "--seed")]
    base = os.path.join(ROOT, "build", "tsg_in")
    if not ids:
        ids = sorted(d for d in os.listdir(base) if os.path.exists(os.path.join(base, d, "05.png")))
    torch.set_num_threads(8)
    pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
                                                            variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()
    session = new_session("isnet-general-use")
    for sid in ids:
        src = Image.open(os.path.join(base, sid, "05.png")).convert("RGBA")
        bg = Image.new("RGBA", src.size, (128, 130, 136, 255))
        bg.alpha_composite(src)
        init = bg.convert("RGB").resize((1024, 1024), Image.LANCZOS)
        g = torch.Generator("cpu").manual_seed(seed)
        img = pipe(prompt=PROMPT, negative_prompt=NEG, image=init, strength=strength, num_inference_steps=36,
                   guidance_scale=6.5, generator=g).images[0]
        out = remove(img, session=session).convert("RGBA")
        out.save(os.path.join(base, sid, out_name))
        print("OK", sid, flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
