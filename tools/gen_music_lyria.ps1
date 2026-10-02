<#
.SYNOPSIS
  Genera la banda sonora con Google Lyria (API de Gemini): un bucle de 30 s por bioma + menú.
.DESCRIPTION
  Usa el modelo lyria-3-clip-preview (clips instrumentales de 30 s, 44.1 kHz estéreo) y guarda MP3 en
  assets/audio/music/<pista>.mp3. El juego prefiere el .mp3 si existe y si no usa el .wav sintetizado.
  El reproductor encadena el clip consigo mismo con fundido para que el bucle no se note.
  Requiere la variable de entorno GEMINI_API_KEY (Google AI Studio, con facturación activa).
.EXAMPLE
  .\tools\gen_music_lyria.ps1
  .\tools\gen_music_lyria.ps1 -Only vacio -Force
#>
param([string]$Only = "", [switch]$Force, [string]$Model = "lyria-3-clip-preview")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$key = $env:GEMINI_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("GEMINI_API_KEY", "User") }
if (-not $key) {
    Write-Host "Falta GEMINI_API_KEY. Créala en https://aistudio.google.com/apikey y guárdala con:" -ForegroundColor Red
    Write-Host '  [Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "AIza...", "User")'
    exit 1
}

$base = "Instrumental only, no vocals, no lyrics. High-production soundtrack for a modern sci-fi space shooter browser MMO, cinematic hybrid of orchestra and modern electronic sound design, polished mix, wide stereo. Designed to loop seamlessly as background music during gameplay, steady energy without a big intro or ending."
$tracks = [ordered]@{
    "menu"        = "Main menu hangar theme: heroic and hopeful, warm analog synth pads, slow brass swells, soft pulsing arpeggio, subtle percussion, sense of a vast space station, 90 BPM."
    "ferron"      = "Rusty asteroid belt combat: industrial and driving, punchy electronic drums with metallic impacts, distorted synth bass, tense string ostinato, mechanical textures, 105 BPM."
    "vesper"      = "Organic purple alien nebula: eerie and mysterious, breathing evolving pads, deep heartbeat-like drums, wet glassy textures, distant wordless choir, 84 BPM."
    "prismaticos" = "Crystal fields: shimmering and bright yet tense, glassy bell arpeggios, crystalline synth plucks, light energetic electronic drums, airy strings, 112 BPM."
    "vacio"       = "Void fracture: dark ambient horror, deep sub drones, sparse distant booms, dissonant low strings, ominous low choir, unsettling reversed swells, 66 BPM."
    "leviatan"    = "Leviathan garden: epic oceanic and colossal, massive low brass, taiko war drums, ethereal choir pads, slow majestic progression, 90 BPM."
}
$outDir = Join-Path $root "assets/audio/music"
New-Item -ItemType Directory -Force $outDir | Out-Null
foreach ($id in $tracks.Keys) {
    if ($Only -and $id -ne $Only) { continue }
    $dest = Join-Path $outDir "$id.mp3"
    if ((Test-Path $dest) -and -not $Force) { Write-Host "= $id (ya existe)"; continue }
    Write-Host "> $id" -ForegroundColor Cyan
    $body = @{ model = $Model; input = "$base $($tracks[$id])" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Method Post -Uri "https://generativelanguage.googleapis.com/v1beta/interactions" `
            -Headers @{ "x-goog-api-key" = $key } -ContentType "application/json; charset=utf-8" `
            -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 300
        $data = $null
        foreach ($step in $res.steps) {
            foreach ($c in $step.model_output.content) {
                if ($c.audio -and $c.audio.data) { $data = $c.audio.data }
            }
        }
        if (-not $data) { Write-Host "  Sin audio en la respuesta:" -ForegroundColor Red; $res | ConvertTo-Json -Depth 6 | Select-Object -First 40; continue }
        [IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String($data))
        Write-Host "  OK -> $dest" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails) { Write-Host "  $($_.ErrorDetails.Message)" }
    }
}
