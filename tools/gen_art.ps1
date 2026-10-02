<#
.SYNOPSIS
  Genera sprites del juego con la API de imágenes de OpenAI (gpt-image-1).

.DESCRIPTION
  Lee tools/art_manifest.json y guarda PNG con fondo transparente en assets/sprites/<out>.png.
  Godot los usa automáticamente en lugar de las siluetas procedurales (ver scripts/core/sprite_lib.gd).

  Requiere la variable de entorno OPENAI_API_KEY (no se guarda en el repositorio).

.EXAMPLE
  .\tools\gen_art.ps1                      # genera los que faltan
  .\tools\gen_art.ps1 -Only enemies/xenomita -Force
  .\tools\gen_art.ps1 -Prompt "Nave reparadora..." -Out ships/reparadora
#>
param(
    [string]$Only = "",
    [switch]$Force,
    [string]$Prompt = "",
    [string]$Out = "",
    [int]$Size = 256,
    [ValidateSet("low", "medium", "high")][string]$Quality = "medium"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$key = $env:OPENAI_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
if (-not $key) {
    Write-Host "Falta OPENAI_API_KEY. Configúrala con:" -ForegroundColor Red
    Write-Host '  [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")'
    exit 1
}

$manifest = Get-Content (Join-Path $PSScriptRoot "art_manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$jobs = @()
if ($Prompt -and $Out) {
    $jobs += [pscustomobject]@{ out = $Out; prompt = $Prompt }
} else {
    $jobs = $manifest.assets | Where-Object { -not $Only -or $_.out -eq $Only }
}

Add-Type -AssemblyName System.Drawing

function Save-Resized([byte[]]$bytes, [string]$path, [int]$px) {
    $ms = New-Object IO.MemoryStream(, $bytes)
    $src = [Drawing.Image]::FromStream($ms)
    $dst = New-Object Drawing.Bitmap($px, $px, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.DrawImage($src, 0, 0, $px, $px)
    $dst.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $dst.Dispose(); $src.Dispose(); $ms.Dispose()
}

foreach ($job in $jobs) {
    $dest = Join-Path $root ("assets/sprites/" + $job.out + ".png")
    if ((Test-Path $dest) -and -not $Force) { Write-Host "= $($job.out) (ya existe)"; continue }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Write-Host "> Generando $($job.out)..." -ForegroundColor Cyan
    $body = @{
        model      = "gpt-image-1"
        prompt     = "$($manifest.style) Subject: $($job.prompt)"
        size       = "1024x1024"
        background = "transparent"
        quality    = $Quality
        n          = 1
    } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/images/generations" `
            -Headers @{ Authorization = "Bearer $key" } -ContentType "application/json; charset=utf-8" `
            -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 300
        $bytes = [Convert]::FromBase64String($res.data[0].b64_json)
        $raw = Join-Path $root ("assets/source/" + $job.out + "_1024.png")
        New-Item -ItemType Directory -Force (Split-Path $raw) | Out-Null
        [IO.File]::WriteAllBytes($raw, $bytes)
        Save-Resized $bytes $dest $Size
        Write-Host "  OK -> $dest" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails) { Write-Host "  $($_.ErrorDetails.Message)" }
    }
}
