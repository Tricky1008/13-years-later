<#>
.SYNOPSIS
    Run VIctory-NVIDIA with Series S 720p settings and memory optimizations.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Exe
)

$ErrorActionPreference = "Stop"

$VictoryDir = "$PSScriptRoot\BuildConfig\VIctory-NVIDIA"
$Build = "diag"

$victoryExe = Join-Path $VictoryDir "target\$Build\victory.exe"
if (-not (Test-Path $victoryExe)) {
    Write-Host "No $victoryExe. Build it first." -ForegroundColor Red
    return
}

# Smooth Motion copy
$sm = Join-Path (Split-Path $victoryExe) 'victory_sm.exe'
if (-not (Test-Path $sm) -or (Get-Item $sm).LastWriteTime -lt (Get-Item $victoryExe).LastWriteTime) {
    Copy-Item $victoryExe $sm -Force
}
$victoryExe = $sm

# Clear old VICTORY_ env vars (keep config paths)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }

# Set all environment variables directly
$env:VICTORY_TEXTURE_NO_WAIT = '1'
$env:VICTORY_RELAY = '2'
$env:VICTORY_CARD_STEPS = '1'
$env:VICTORY_WIDE_BACK = '1'
$env:VICTORY_CARD_REHASH_RUNS = '1'
$env:VICTORY_JOIN_COPIES = '1'
$env:VICTORY_INDIRECT_WINDOW = '1'
$env:VICTORY_RELAY_COPY = '1'
$env:VICTORY_INDIRECT_BATCH = '2'
$env:VICTORY_MAP_THREADS = '1'
$env:VICTORY_TITLE_PRIORITIES = '0'
$env:VICTORY_CARD_AWAKE = '1'
$env:VICTORY_SHOW_AFTER = '1'
$env:VICTORY_AMBIENT = '0.8'
$env:VICTORY_D3D12_DRED = 'light'
$env:VICTORY_SKIP_PIPELINES = 'none'
$env:VICTORY_THIN = '1'
$env:VICTORY_THIN_THREADS = '8'
$env:VICTORY_JOIN_PARTS = '8'
$env:VICTORY_UPLOAD_AHEAD = '1'
$env:VICTORY_ASYNC_SUBMIT = '1'
$env:VICTORY_LEVELS_ON_DEMAND = '1'
$env:VICTORY_CARD_ROOM_FOR_BUFFERS = '1'
$env:VICTORY_CARD_WINDOWS_MB = '1024'
$env:VICTORY_WINDOWS_BAR_MB = '512'
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'
$env:VICTORY_CARD_BUFFERS_MIN_MB = '1'
$env:VICTORY_CARD_BUFFERS_MB = '1024'
$env:VICTORY_CARD_WINDOWS_MB = '1024'
$env:VICTORY_WINDOWS_BAR_MB = '512'
$env:VICTORY_COMPOSE = '1'
$env:VICTORY_AMBIENT_AIR = '1.5'
$env:VICTORY_AMBIENT_MOST = '2'
$env:VICTORY_NAN_SCRUB = '1'
$env:VICTORY_PIPELINE_WAIT_MS = '10000'
$env:VICTORY_PIPELINE_WAIT_ONCE = '1'
$env:VICTORY_DYNAMIC_SLOTS = '262144'
$env:VICTORY_RENDER_SCALE = '0.667'
$env:VICTORY_OWN_UPSCALER = '1'
$env:VICTORY_BVH_MISS = '1'

Write-Host "Series S, rendering at 720p (render scale 0.667)" -ForegroundColor Green

$Exe = (Resolve-Path $Exe).Path
$runArgs = @('run', $Exe, '--execute', '--console', 'series-s')

Push-Location $VictoryDir
try { & $victoryExe @runArgs } finally { Pop-Location }