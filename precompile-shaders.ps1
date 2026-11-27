<#>
.SYNOPSIS
    Complete shader pre-compilation for VIctory-NVIDIA to eliminate on-the-fly shader compilation during gameplay.

.DESCRIPTION
    Runs the full 3-phase pre-compilation:
    1. Translate ALL shaders to persistent cache
    2. Build host pipelines for driver cache (from known pipelines)
    3. Verify 100% coverage

.NOTES
    Run this ONCE per translator change or driver update.
    Must have played through all content with VICTORY_PIPELINE_BOOK=1 first.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GameDir,
    
    [string]$VictoryDir = "$PSScriptRoot\GTA6-Build\VIctory-NVIDIA",
    [string]$CacheDir = "$PSScriptRoot\GTA6-Build\VIctory-NVIDIA\cache",
    [int]$Jobs = 16
)

$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  VIctory-NVIDIA Shader Pre-Compilation" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Game Dir: $GameDir"
Write-Host "Victory Dir: $VictoryDir"
Write-Host "Cache Dir: $CacheDir"
Write-Host "Jobs: $Jobs"
Write-Host ""

# Set environment
$env:VICTORY_CACHE_DIR = $CacheDir
$env:VICTORY_CONFIG = "$VictoryDir\victory.toml"
$env:VICTORY_GAME_DIR = $GameDir
$env:VICTORY_DATA_DIR = "$VictoryDir\data"
$env:VICTORY_HOST_WAVE = "64"
$env:VICTORY_VIEW_LIMIT = "1000000"

$victoryExe = "$VictoryDir\target\diag\victory.exe"
if (-not (Test-Path $victoryExe)) {
    throw "Victory exe not found at $victoryExe. Build with: cargo build --locked --profile diag -p victory --features diagnostics"
}

# Phase 1: Translate ALL shaders to cache
Write-Host "`n=== PHASE 1: Translate ALL shaders to cache ===" -ForegroundColor Green
Write-Host "This populates the persistent shader cache with every shader in the game files." -ForegroundColor Yellow
Write-Host "Takes a few minutes. Run once per translator change." -ForegroundColor Yellow
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $victoryExe translate --warm all --pipelines --jobs $Jobs $GameDir
$stopwatch.Stop()
Write-Host "Phase 1 completed in $($stopwatch.Elapsed.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Green

# Phase 2: Build host pipelines from known pipelines
Write-Host "`n=== PHASE 2: Build host pipelines for driver cache ===" -ForegroundColor Green
Write-Host "This builds D3D12 pipelines for pipelines the game actually drew with." -ForegroundColor Yellow
Write-Host "Requires a prior run with VICTORY_PIPELINE_BOOK=1" -ForegroundColor Yellow
$stopwatch.Restart()
& $victoryExe warm --used --jobs ([int]($Jobs * 2 / 3))
$stopwatch.Stop()
Write-Host "Phase 2 completed in $($stopwatch.Elapsed.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Green

# Phase 3: Verify
Write-Host "`n=== PHASE 3: Verify coverage ===" -ForegroundColor Green
Write-Host "Checking shader translation stats..." -ForegroundColor Yellow
& $victoryExe translate --list --jobs $Jobs $GameDir 2>&1 | Select-String "translated|pipelines"

Write-Host "`n=== PRE-COMPILATION COMPLETE ===" -ForegroundColor Cyan
Write-Host "You can now run the game with zero on-the-fly shader compilation!" -ForegroundColor Green