<#
.SYNOPSIS
  Genera arte del juego con la API de imágenes de OpenAI (gpt-image-1).

.DESCRIPTION
  Lee tools/art_manifest.json y guarda PNG en assets/<out>.png (sprites, iconos, fondos).
  Godot los usa automáticamente (scripts/core/sprite_lib.gd). Requiere OPENAI_API_KEY.

  Campos por asset: out, prompt, style (clave de "styles", por defecto "sprite"),
  size (tamaño API, por defecto 1024x1024), out_w/out_h (tamaño final), transparent (true por defecto).

.EXAMPLE
  .\tools\gen_art.ps1                              # genera los que faltan
  .\tools\gen_art.ps1 -Group sprites/enemies/      # solo un grupo
  .\tools\gen_art.ps1 -Only sprites/enemies/xenomita -Force
  .\tools\gen_art.ps1 -Shard 0 -Shards 3           # reparte el trabajo en 3 procesos paralelos
#>
param(
    [string]$ManifestFile = "art_manifest.json",
    [string]$Only = "",
    [string]$Group = "",
    [switch]$Force,
    [int]$Shard = 0,
    [int]$Shards = 1,
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

$manifest = Get-Content (Join-Path $PSScriptRoot $ManifestFile) -Raw -Encoding UTF8 | ConvertFrom-Json
$all = @($manifest.assets | Where-Object {
        (-not $Only -or $_.out -eq $Only) -and (-not $Group -or $_.out.StartsWith($Group))
    })
$jobs = @()
for ($i = 0; $i -lt $all.Count; $i++) { if ($i % $Shards -eq $Shard) { $jobs += $all[$i] } }

Add-Type -AssemblyName System.Drawing

function Save-Resized([byte[]]$bytes, [string]$path, [int]$w, [int]$h) {
    $ms = New-Object IO.MemoryStream(, $bytes)
    $src = [Drawing.Image]::FromStream($ms)
    $dst = New-Object Drawing.Bitmap($w, $h, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.DrawImage($src, 0, 0, $w, $h)
    $dst.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $dst.Dispose(); $src.Dispose(); $ms.Dispose()
}

foreach ($job in $jobs) {
    $dest = Join-Path $root ("assets/" + $job.out + ".png")
    if ((Test-Path $dest) -and -not $Force) { Write-Host "= $($job.out) (ya existe)"; continue }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    $styleKey = if ($job.style) { $job.style } else { "sprite" }
    $style = $manifest.styles.$styleKey
    $size = if ($job.size) { $job.size } else { "1024x1024" }
    $transparent = if ($null -ne $job.transparent) { [bool]$job.transparent } else { $true }
    $ow = if ($job.out_w) { [int]$job.out_w } else { 256 }
    $oh = if ($job.out_h) { [int]$job.out_h } else { 256 }
    $body = @{
        model      = "gpt-image-1"
        prompt     = "$style Subject: $($job.prompt)"
        size       = $size
        background = $(if ($transparent) { "transparent" } else { "opaque" })
        quality    = $(if ($job.quality) { $job.quality } else { $Quality })
        n          = 1
    } | ConvertTo-Json
    $ok = $false
    for ($try = 1; $try -le 6 -and -not $ok; $try++) {
        Write-Host "> $($job.out) (intento $try)" -ForegroundColor Cyan
        try {
            $res = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/images/generations" `
                -Headers @{ Authorization = "Bearer $key" } -ContentType "application/json; charset=utf-8" `
                -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 300
            $bytes = [Convert]::FromBase64String($res.data[0].b64_json)
            $raw = Join-Path $root ("assets/source/" + $job.out + "_src.png")
            New-Item -ItemType Directory -Force (Split-Path $raw) | Out-Null
            [IO.File]::WriteAllBytes($raw, $bytes)
            Save-Resized $bytes $dest $ow $oh
            Write-Host "  OK -> $dest" -ForegroundColor Green
            $ok = $true
        } catch {
            $msg = $_.Exception.Message
            $detail = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { "" }
            if ($msg -match "429" -and $detail -notmatch "insufficient_quota|credit_balance") {
                Write-Host "  límite de velocidad, esperando..." -ForegroundColor Yellow
                Start-Sleep -Seconds (15 * $try)
            } else {
                Write-Host "  ERROR: $msg $detail" -ForegroundColor Red
                break
            }
        }
    }
}
Write-Host "FIN shard $Shard"
