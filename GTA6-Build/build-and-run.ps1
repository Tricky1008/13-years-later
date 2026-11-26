<#>
.SYNOPSIS
    Build and run GTA VI on RTX 5060 8GB VRAM using the best available forks.
    
.DESCRIPTION
    This script builds and runs the game using:
    1. victory-nvidia-8gb (soldsawn) - SPECIFICALLY tuned for 8GB NVIDIA GPUs (Wave32)
    2. VIctory-NVIDIA (trustno1-coder) - Series S half-scale mode for higher FPS
    3. Uses Xbox2Windows shader translation pipeline for pre-compiled shaders
    
.REQUIREMENTS
    - Windows 10/11 x64
    - Rust (pinned toolchain via rustup)
    - Visual Studio 2022 with "Desktop development with C++" workload
    - Windows SDK 10.0.26100+ (for DXC 1.8+)
    - Game files (Xbox Series X|S dump)
    - 32GB+ RAM recommended (you have 32GB DDR5)

.NOTES
    For RTX 5060 8GB:
    - Use VICTORY_TEXTURE_DROP_MIPS=2 to fit in VRAM
    - Use Series S profile (--console series-s) for lower memory
    - Use half render scale (VICTORY_RENDER_SCALE=0.5)
    - Enable NVIDIA Smooth Motion for 2x perceived smoothness
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GameExePath,
    
    [string]$BuildType = "victory-nvidia-8gb",  # victory-nvidia-8gb | victory-nvidia | both
    
    [switch]$PrecompileShaders,
    
    [switch]$NoSmoothMotion,
    
    [switch]$QualityMode,
    
    [string]$Resolution = "540p"  # 540p | 720p | 1080p (Series S)
)

# ============================================================================
# CONFIGURATION
# ============================================================================
$ErrorActionPreference = "Stop"
$BASE_DIR = "E:\GTA 6\GTA6-Build"
$GAME_EXE = Resolve-Path $GameExePath

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  GTA VI PC Build & Run - RTX 5060 8GB" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Game EXE: $GAME_EXE"
Write-Host "Build Type: $BuildType"
Write-Host "Resolution: $Resolution"
Write-Host ""

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================
function Check-Prerequisites {
    Write-Host "[CHECK] Verifying prerequisites..." -ForegroundColor Yellow
    
    # Check Rust
    if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
        throw "Rust not found. Install from https://rustup.rs/"
    }
    $rustVersion = rustc --version
    Write-Host "  Rust: $rustVersion" -ForegroundColor Green
    
    # Check Cargo
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        throw "Cargo not found."
    }
    
    # Check MSVC (Visual Studio)
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        $vsPath = & $vsWhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vsPath) {
            Write-Host "  Visual Studio: $vsPath" -ForegroundColor Green
            # Enter VS developer environment
            $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvars) {
                Write-Host "  Entering VS developer environment..." -ForegroundColor Yellow
                & cmd /c "`"$vcvars`" && set" | ForEach-Object {
                    if ($_ -match '^(.+?)=(.*)$') {
                        $env:$matches[1] = $matches[2]
                    }
                }
            }
        }
    } else {
        Write-Host "  WARNING: Visual Studio not found via vswhere. Build may fail." -ForegroundColor Red
    }
    
    # Check Windows SDK / DXC
    $dxcPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\dxc.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\dxc.exe",
        "${env:XCL_DXC_DIR}\dxc.exe"
    )
    $foundDxc = $false
    foreach ($p in $dxcPaths) {
        if (Test-Path $p) {
            Write-Host "  DXC: $p" -ForegroundColor Green
            $env:XCL_DXC_DIR = Split-Path $p
            $foundDxc = $true
            break
        }
    }
    if (-not $foundDxc) {
        Write-Host "  WARNING: DXC 1.8+ not found. Shader compilation may be slower or fail." -ForegroundColor Red
        Write-Host "  Download from: https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2502" -ForegroundColor Yellow
    }
    
    # Verify game exe exists
    if (-not (Test-Path $GAME_EXE)) {
        throw "Game executable not found: $GAME_EXE"
    }
    Write-Host "  Game EXE: OK" -ForegroundColor Green
}

# ============================================================================
# BUILD VICTORY-NVIDIA-8GB (soldsawn) - BEST FOR 8GB VRAM
# ============================================================================
function Build-VictoryNvidia8GB {
    Write-Host "`n[BUILD] victory-nvidia-8gb (soldsawn - 8GB optimized)..." -ForegroundColor Cyan
    $repoDir = Join-Path $BASE_DIR "victory-nvidia-8gb"
    Set-Location $repoDir
    
    # Check for victory.toml
    $configFile = Join-Path $repoDir "victory.toml"
    if (-not (Test-Path $configFile)) {
        Write-Host "  Creating victory.toml from example..." -ForegroundColor Yellow
        Copy-Item "victory.example.toml" "victory.toml"
        Write-Host "  IMPORTANT: Edit victory.toml and set your game paths!" -ForegroundColor Red
        Write-Host "  Required keys: game_dir, shader_archives, data_dir, cache_dir" -ForegroundColor Red
        Read-Host "  Press Enter after editing victory.toml..."
    }
    
    # Build release
    Write-Host "  Building release binary (this takes 5-15 minutes)..." -ForegroundColor Yellow
    cargo build --release --bin victory
    
    $exePath = Join-Path $repoDir "target\release\victory.exe"
    if (Test-Path $exePath) {
        Write-Host "  Build SUCCESS: $exePath" -ForegroundColor Green
        return $exePath
    } else {
        throw "Build failed - victory.exe not found"
    }
}

# ============================================================================
# BUILD VICTORY-NVIDIA (trustno1-coder) - SERIES S HALF-SCALE
# ============================================================================
function Build-VictoryNvidia {
    Write-Host "`n[BUILD] VIctory-NVIDIA (trustno1-coder - Series S half-scale)..." -ForegroundColor Cyan
    $repoDir = Join-Path $BASE_DIR "VIctory-NVIDIA"
    Set-Location $repoDir
    
    # Check for victory.toml
    $configFile = Join-Path $repoDir "victory.toml"
    if (-not (Test-Path $configFile)) {
        Write-Host "  Creating victory.toml from example..." -ForegroundColor Yellow
        Copy-Item "victory.example.toml" "victory.toml"
        Write-Host "  IMPORTANT: Edit victory.toml and set your game paths!" -ForegroundColor Red
        Read-Host "  Press Enter after editing victory.toml..."
    }
    
    # Build diagnostics profile (needed for play-nvidia.ps1)
    Write-Host "  Building diagnostics profile (this takes 10-20 minutes)..." -ForegroundColor Yellow
    cargo build --locked --profile diag -p victory --features diagnostics
    
    $exePath = Join-Path $repoDir "target\diag\victory.exe"
    if (Test-Path $exePath) {
        Write-Host "  Build SUCCESS: $exePath" -ForegroundColor Green
        return $exePath
    } else {
        throw "Build failed - victory.exe not found in target\diag"
    }
}

# ============================================================================
# PRECOMPILE SHADERS USING XBOX2WINDOWS PIPELINE
# ============================================================================
function Precompile-Shaders {
    param($VictoryExe, $ShaderArchivesPath)
    
    Write-Host "`n[SHADERS] Precompiling shaders ahead of time..." -ForegroundColor Cyan
    Write-Host "  This translates all ~26,500 shaders and builds pipeline cache." -ForegroundColor Yellow
    Write-Host "  Takes 5-15 minutes depending on CPU." -ForegroundColor Yellow
    
    # Using victory's built-in shader translation
    & $VictoryExe shaders $ShaderArchivesPath --warm all --jobs 16
    
    # Warm pipelines from previous runs
    & $VictoryExe warm --used
    
    Write-Host "  Shader precompilation complete!" -ForegroundColor Green
}

# ============================================================================
# RUN VICTORY-NVIDIA-8GB
# ============================================================================
function Run-VictoryNvidia8GB {
    param($ExePath)
    
    Write-Host "`n[RUN] victory-nvidia-8gb with 8GB optimizations..." -ForegroundColor Cyan
    
    $scriptPath = Join-Path $BASE_DIR "victory-nvidia-8gb\scripts\play-nvidia-8gb.ps1"
    
    $params = @(
        "-Exe", "`"$GAME_EXE`""
    )
    
    if ($NoSmoothMotion) { $params += "-NoOverlay" }
    if ($QualityMode) { 
        $env:VICTORY_RELAY = "1"
        $env:VICTORY_CARD_STEPS = "0"
        $env:VICTORY_TEXTURE_NO_WAIT = "0"
    }
    
    # 8GB VRAM critical settings
    $env:VICTORY_TEXTURE_DROP_MIPS = "2"
    $env:VICTORY_RESOLUTION = "1920x1080"
    $env:VICTORY_COPY_PLAIN = "1"
    $env:VICTORY_WINDOW_PERCENT = "88"
    
    Write-Host "  Settings: TEXTURE_DROP_MIPS=2, RESOLUTION=1080p, COPY_PLAIN=1" -ForegroundColor Yellow
    Write-Host "  Press F10 to toggle performance overlay" -ForegroundColor Yellow
    Write-Host "  Starting..." -ForegroundColor Green
    
    & $scriptPath @params
}

# ============================================================================
# RUN VICTORY-NVIDIA (Series S Half-Scale)
# ============================================================================
function Run-VictoryNvidia {
    param($ExePath)
    
    Write-Host "`n[RUN] VIctory-NVIDIA (Series S half-scale)..." -ForegroundColor Cyan
    
    $scriptPath = Join-Path $BASE_DIR "VIctory-NVIDIA\scripts\play-nvidia.ps1"
    
    $params = @(
        "-Exe", "`"$GAME_EXE`""
    )
    
    if ($NoSmoothMotion) { $params += "-NoSmoothMotion" }
    if ($QualityMode) { $params += "-Quality" }
    if ($Resolution -ne "540p") { 
        # Map resolution to script
        $resScript = "scripts\play-S-$Resolution.ps1"
        if (Test-Path (Join-Path $BASE_DIR "VIctory-NVIDIA\$resScript")) {
            $scriptPath = Join-Path $BASE_DIR "VIctory-NVIDIA\$resScript"
        } else {
            $params += "-Resolution", $Resolution.Replace("p","")
        }
    }
    
    # Critical settings for 8GB VRAM
    $env:VICTORY_TEXTURE_DROP_MIPS = "2"
    $env:VICTORY_RENDER_SCALE = "0.5"
    $env:VICTORY_OWN_UPSCALER = "1"
    $env:VICTORY_BVH_MISS = "1"
    $env:VICTORY_CARD_BUFFERS_MIN_MB = "1"
    $env:VICTORY_CARD_BUFFERS_MB = "1536"
    $env:VICTORY_PIPELINE_WAIT_MS = "10000"
    $env:VICTORY_DYNAMIC_SLOTS = "524288"
    $env:VICTORY_COMPOSE = "1"
    $env:VICTORY_NO_WATCHDOG = "1"
    $env:VICTORY_AMBIENT_AIR = "1.5"
    $env:VICTORY_AMBIENT_MOST = "2"
    $env:VICTORY_NAN_SCRUB = "1"
    $env:VICTORY_PIPELINE_WAIT_ONCE = "1"
    
    Write-Host "  Settings: Series S, Half-scale (960x540), Own Upscaler, BVH Miss, Card Compares" -ForegroundColor Yellow
    Write-Host "  Expected: ~18-22 FPS on RTX 5060 8GB (with Smooth Motion: 2x perceived)" -ForegroundColor Yellow
    Write-Host "  Starting..." -ForegroundColor Green
    
    & $scriptPath @params
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
try {
    Check-Prerequisites
    
    $builtExes = @{}
    
    if ($BuildType -eq "victory-nvidia-8gb" -or $BuildType -eq "both") {
        $builtExes["victory-nvidia-8gb"] = Build-VictoryNvidia8GB
    }
    
    if ($BuildType -eq "victory-nvidia" -or $BuildType -eq "both") {
        $builtExes["victory-nvidia"] = Build-VictoryNvidia
    }
    
    # Precompile shaders if requested
    if ($PrecompileShaders -and $builtExes.Count -gt 0) {
        # Need to read shader_archives from victory.toml
        $firstExe = $builtExes.Values[0]
        # You'll need to provide shader archives path
        Write-Host "  Provide shader archives path for precompilation:" -ForegroundColor Yellow
        $shaderPath = Read-Host "  Shader archives folder (e.g., D:\Game\shaders)"
        if (Test-Path $shaderPath) {
            Precompile-Shaders -VictoryExe $firstExe -ShaderArchivesPath $shaderPath
        }
    }
    
    # Run the selected build
    Write-Host "`n===========================================" -ForegroundColor Cyan
    Write-Host "  READY TO RUN" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    
    if ($builtExes.ContainsKey("victory-nvidia-8gb") -and ($BuildType -eq "victory-nvidia-8gb" -or $BuildType -eq "both")) {
        Write-Host "`n1. Run victory-nvidia-8gb (BEST for 8GB VRAM - ~6-10 FPS native)"
        Run-VictoryNvidia8GB -ExePath $builtExes["victory-nvidia-8gb"]
    }
    
    if ($builtExes.ContainsKey("victory-nvidia") -and ($BuildType -eq "victory-nvidia" -or $BuildType -eq "both")) {
        Write-Host "`n2. Run VIctory-NVIDIA (Series S half-scale - ~18-22 FPS native)"
        Run-VictoryNvidia -ExePath $builtExes["victory-nvidia"]
    }
    
} catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}