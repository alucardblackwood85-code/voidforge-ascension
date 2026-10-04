"""Gemini como diseñador de sonido: escucha efectos .wav y devuelve una crítica con cambios concretos.

La API de Gemini no genera ni edita efectos de sonido, pero sí escucha audio. Este script le envía los
.wav indicados con el contexto del juego y guarda su respuesta (JSON) en build/sfx_review/<nombre>.json
para aplicar los cambios en el sintetizador (scripts/tools/gen_sfx.gd).

Uso:
    python tools/gemini_sfx_review.py <grupo> <wav...> [--brief "texto"] [--model gemini-3.8-flash]
Requiere GEMINI_API_KEY (variable de entorno o de usuario de Windows). La clave nunca se imprime.
"""
import base64, json, os, sys, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "sfx_review")

CONTEXT = ("You are a senior sound designer for a modern browser space MMO in the style of DarkOrbit "
           "(isometric sci-fi ship combat, energy lasers whose sound and color depend on the ammo type, "
           "punchy but not tiring when repeated every 1.2 seconds). The current sounds are procedurally "
           "synthesized (oscillators, unison, resonant filters, noise, sub thump, reverb). Avoid anything "
           "that sounds like retro 8-bit/chiptune arcade.")


def api_key() -> str:
    k = os.environ.get("GEMINI_API_KEY", "")
    if not k and os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = winreg.QueryValueEx(h, "GEMINI_API_KEY")[0]
        except OSError:
            pass
    if not k:
        sys.exit("Falta GEMINI_API_KEY")
    return k


def main() -> None:
    args = sys.argv[1:]
    model = "gemini-3.8-flash"
    brief = ""
    if "--model" in args:
        i = args.index("--model"); model = args[i + 1]; del args[i:i + 2]
    if "--brief" in args:
        i = args.index("--brief"); brief = args[i + 1]; del args[i:i + 2]
    group, files = args[0], args[1:]
    parts = [{"text": CONTEXT + "\n\n" + brief + "\n\nYou will hear these sounds in order: " +
              ", ".join(os.path.basename(f) for f in files) + "."}]
    for f in files:
        parts.append({"text": "Sound: " + os.path.basename(f)})
        parts.append({"inline_data": {"mime_type": "audio/wav", "data": base64.b64encode(open(f, "rb").read()).decode()}})
    parts.append({"text": (
        "For EACH sound return: name, score 1-10 (modern sci-fi MMO quality), what you actually hear, "
        "what sounds retro/cheap or wrong, and concrete synthesis changes (pitch start/end in Hz, duration in s, "
        "filter cutoff/resonance, layers to add or remove, reverb, distortion). Then a short overall verdict on "
        "how the set works together. Answer ONLY with JSON: {\"sounds\": [{\"name\", \"score\", \"heard\", "
        "\"problems\", \"changes\"}], \"overall\": \"...\"}")})
    body = {"contents": [{"role": "user", "parts": parts}], "generationConfig": {"responseMimeType": "application/json", "temperature": 0.4}}
    # Reintentos ante saturación (503/429) y modelo de respaldo.
    res = None
    for attempt, m in enumerate([model, model, model, "gemini-3.5-flash", "gemini-2.5-pro"]):
        req = urllib.request.Request(
            f"https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent",
            data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": api_key()})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                res = json.load(r)
            print(f"(modelo {m})", file=sys.stderr)
            break
        except urllib.error.HTTPError as e:
            print(f"{m}: HTTP {e.code}, reintento", file=sys.stderr)
            if e.code not in (404, 429, 500, 503):
                raise
            time.sleep(10 * (attempt + 1))
    if res is None:
        sys.exit("Gemini no respondió")
    text = res["candidates"][0]["content"]["parts"][0]["text"]
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, group + ".json")
    open(path, "w", encoding="utf-8").write(text)
    print(text)


if __name__ == "__main__":
    main()
