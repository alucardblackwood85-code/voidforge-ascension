<#
.SYNOPSIS
  Genera las voces de la IA de la nave con la API de texto a voz de OpenAI (voz femenina).
.DESCRIPTION
  Guarda WAV crudos en assets/audio/voice_raw/. Después, el filtro robótico de Godot los procesa:
    godot --headless --script res://scripts/tools/robotize_voice.gd
  Resultado final en assets/audio/voice/<id>.wav
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$key = $env:OPENAI_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
if (-not $key) { Write-Host "Falta OPENAI_API_KEY" -ForegroundColor Red; exit 1 }

$lines = [ordered]@{
    "low_hull"      = "Warning. Hull integrity critical."
    "shield_down"   = "Shields depleted."
    "objective"     = "Objective complete. Proceed to extraction."
    "sector_alert"  = "Alert. Hostile reinforcements detected."
    "rank_up"       = "Promotion granted."
}
$outDir = Join-Path $root "assets/audio/voice_raw"
New-Item -ItemType Directory -Force $outDir | Out-Null
foreach ($id in $lines.Keys) {
    $dest = Join-Path $outDir "$id.wav"
    if ((Test-Path $dest) -and -not $Force) { Write-Host "= $id"; continue }
    $body = @{
        model           = "gpt-4o-mini-tts"
        voice           = "nova"
        input           = $lines[$id]
        instructions    = "You are the onboard AI of a military starship. Speak in a calm, precise, emotionless synthetic female voice, clearly articulated, slightly clipped, like a cockpit warning system."
        response_format = "wav"
    } | ConvertTo-Json
    Write-Host "> $id" -ForegroundColor Cyan
    Invoke-WebRequest -Method Post -Uri "https://api.openai.com/v1/audio/speech" -Headers @{ Authorization = "Bearer $key" } `
        -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body)) -OutFile $dest -TimeoutSec 120
    Write-Host "  OK $dest" -ForegroundColor Green
}
