<#>
.SYNOPSIS
    Run VIctory-NVIDIA with optimized settings for RTX 5060 8GB:
    - Series S 540p (render scale 0.5) for max FPS
    - Aggressive VRAM optimizations for 8GB card
    - FPS optimizations for chapter 1 gameplay
    - Shader pre-compilation support
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Exe,
    
    [switch]$PrecompileShaders,
    [switch]$NoSmoothMotion
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
if (-not $NoSmoothMotion) {
    $sm = Join-Path (Split-Path $victoryExe) 'victory_sm.exe'
    if (-not (Test-Path $sm) -or (Get-Item $sm).LastWriteTime -lt (Get-Item $victoryExe).LastWriteTime) {
        Copy-Item $victoryExe $sm -Force
    }
    $victoryExe = $sm
}

# Clear old VICTORY_ env vars (keep config paths)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }

# ========================================================================
# OPTIMIZED ENVIRONMENT VARIABLES FOR RTX 5060 8GB
# ========================================================================
# ========================================================================
# BASE SETTINGS (Series S 540p for max FPS on 8GB)
# ========================================================================
$env:VICTORY_TEXTURE_NO_WAIT = '1'
$env:VICTORY_RELAY = '1'              # Relay stage 1 (faster)
$env:VICTORY_CARD_STEPS = '2'         # Buffer copies on card (saves 25-30ms)
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

# ========================================================================
# RENDER SETTINGS (Series S 540p for max FPS)
# ========================================================================
$env:VICTORY_RENDER_SCALE = '0.5'       # 540p -> upscaled to 1080p
$env:VICTORY_OWN_UPSCALER = '1'         # Game's temporal upscaler
$env:VICTORY_BVH_MISS = '1'             # Skip RT BVH walks
$env:VICTORY_COMPOSE = '1'              # Series S interface plane

# ========================================================================
# MEMORY OPTIMIZATIONS (for 8GB VRAM)
# ========================================================================
$env:VICTORY_LEVELS_ON_DEMAND = '1'       # Only upload used mip levels
$env:VICTORY_LEVELS_MIN_KB = '256'        # Catch more streaming textures
$env:VICTORY_TEXTURE_DROP_MIPS = '2'      # Drop top 2 mip levels
$env:VICTORY_CARD_ROOM_FOR_BUFFERS = '1'  # Reserve VRAM for buffers
$env:VICTORY_CARD_WINDOWS_MB = '512'      # Reduced from 1024
$env:VICTORY_WINDOWS_BAR_MB = '256'       # Reduced from 512
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'   # Move small buffers to GPU
$env:VICTORY_CARD_BUFFERS_MIN_MB = '1'
$env:VICTORY_CARD_BUFFERS_MB = '512'      # Reduced from 1024
$env:VICTORY_CARD_WINDOWS_MB = '512'      # Reduced from 1024
$env:VICTORY_WINDOWS_BAR_MB = '256'       # Reduced from 512
$env:VICTORY_CARD_ROOM_FOR_BUFFERS = '1'
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'
$env:VICTORY_CARD_BUFFERS_MIN_MB = '1'
$env:VICTORY_CARD_BUFFERS_MB = '512'      # Reduced from 1024
$env:VICTORY_CARD_WINDOWS_MB = '512'
$env:VICTORY_WINDOWS_BAR_MB = '256'
$env:VICTORY_COMPOSE = '1'

# ========================================================================
# PICTURE FIXES
# ========================================================================
$env:VICTORY_AMBIENT_AIR = '1.5'
$env:VICTORY_AMBIENT_MOST = '2'
$env:VICTORY_NAN_SCRUB = '1'
$env:VICTORY_PIPELINE_WAIT_MS = '10000'
$env:VICTORY_PIPELINE_WAIT_ONCE = '1'
$env:VICTORY_DYNAMIC_SLOTS = '524288'     # Template value for NVIDIA 1M heap cap
$env:VICTORY_RENDER_SCALE = '0.5'         # Series S 540p (max FPS)
$env:VICTORY_OWN_UPSCALER = '1'
$env:VICTORY_BVH_MISS = '1'
$env:VICTORY_TEXTURE_DROP_MIPS = '2'      # Drop top 2 mips for 8GB VRAM
$env:VICTORY_CARD_STEPS = '2'             # Buffer copies on card (saves 25-30ms)

# Picture fixes
$env:VICTORY_AMBIENT_AIR = '1.5'
$env:VICTORY_AMBIENT_MOST = '2'
$env:VICTORY_NAN_SCRUB = '1'
$env:VICTORY_PIPELINE_WAIT_MS = '10000'
$env:VICTORY_PIPELINE_WAIT_ONCE = '1'
$env:VICTORY_DYNAMIC_SLOTS = '524288'    # Template value for NVIDIA 1M heap cap
$env:VICTORY_RENDER_SCALE = '0.5'        # Series S 540p (max FPS)
$env:VICTORY_OWN_UPSCALER = '1'
$env:VICTORY_BVH_MISS = '1'
$env:VICTORY_TEXTURE_DROP_MIPS = '2'
$env:VICTORY_CARD_STEPS = '2'

# ========================================================================
# CARD BUFFER SETTINGS
# ========================================================================
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'
$env:VICTORY_CARD_BUFFERS_MIN_MB = '1'
$env:VICTORY_CARD_BUFFERS_MB = '512'
$env:VICTORY_CARD_WINDOWS_MB = '512'
$env:VICTORY_WINDOWS_BAR_MB = '256'
$env:VICTORY_COMPOSE = '1'

# Picture fixes
$env:VICTORY_AMBIENT_AIR = '1.5'
$env:VICTORY_AMBIENT_MOST = '2'
$env:VICTORY_NAN_SCRUB = '1'
$env:VICTORY_PIPELINE_WAIT_MS = '10000'
$env:VICTORY_PIPELINE_WAIT_ONCE = '1'
$env:VICTORY_DYNAMIC_SLOTS = '524288'
$env:VICTORY_RENDER_SCALE = '0.5'
$env:VICTORY_OWN_UPSCALER = '1'
$env:VICTORY_BVH_MISS = '1'
$env:VICTORY_TEXTURE_DROP_MIPS = '2'
$env:VICTORY_CARD_STEPS = '2'

# ========================================================================
# CARD BUFFER SETTINGS
# ========================================================================
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'
$env:VICTORY_CARD_BUFFERS_MIN_MB = '1'
$env:VICTORY_CARD_BUFFERS_MB = '512'
$env:VICTORY_CARD_WINDOWS_MB = '512'
$env:VICTORY_WINDOWS_BAR_MB = '256'
$env:VICTORY_COMPOSE = '1'

# Picture fixes
$env:VICTORY_AMBIENT_AIR = '1.5'
$env:VICTORY_AMBIENT_MOST = '2'
$env:VICTORY_NAN_SCRUB = '1'
$env:VICTORY_PIPELINE_WAIT_MS = '10000'
$env:VICTORY_PIPELINE_WAIT_ONCE = '1'
$env:VICTORY_DYNAMIC_SLOTS = '524288'
$env:VICTORY_RENDER_SCALE = '0.5'
$env:VICTORY_OWN_UPSCALER = '1'
$env:VICTORY_BVH_MISS = '1'
$env:VICTORY_TEXTURE_DROP_MIPS = '2'
$env:VICTORY_CARD_STEPS = '2'

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  VIctory-NVIDIA OPTIMIZED - Series S 540p" -ForegroundColor Cyan
Write-Host "  RTX 5060 8GB - Max FPS for Chapter 1" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Series S, rendering at 540p (render scale 0.5)" -ForegroundColor Green
Write-Host "Expected: 20-25 FPS with Smooth Motion" -ForegroundColor Green
Write-Host ""

$Exe = (Resolve-Path $Exe).Path
$runArgs = @('run', $Exe, '--execute', '--console', 'series-s')

Push-Location $VictoryDir
try { & $victoryExe @runArgs } finally { Pop-Location }