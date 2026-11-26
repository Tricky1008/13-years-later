# Starts the title on an NVIDIA card with the Series S settings measured on an RTX 5070 (about 18-22 fps, no device loss).
#   scripts\play-nvidia.ps1 -Exe <path of your own copy's executable>
# -NoSmoothMotion  run target\<build>\victory.exe itself. By default a copy named victory_sm.exe is started instead,
#                  so a Smooth Motion profile set for that exe in the NVIDIA App applies every time.
# -SeriesX         the Series X profile instead (slower: about 7 fps at half scale)
# -Quality         fewer stretched/jumping bodies and less rainbow skin, at about 13 fps instead of about 20
# -RayTracing      keep the title's ray-tracing passes (off by default: see below)
# -Resolution      the height the game renders at before the title's own upscaler: 2160, 1440, 1080, 720, 540 or 480.
#                  Series S outputs 1080p (so up to 1080 there), Series X 2160p. Default: half the output (540 on S,
#                  1080 on X). The play-S-*.ps1 and play-X-*.ps1 scripts next to this one call it with each.
# -Adapter         on a PC with more than one card, the one to use: part of its name (-Adapter 5060) or its index
#                  (-Adapter '#1'). Default: Windows' default card (the one the main display is on).
# -Build           target\diag (the default, the build all measurements are of) or target\release
#                  (the release build ignores the ray-tracing skip list: VICTORY_SKIP_PIPELINES is a diagnostics switch)
# -More            other settings: -More @{VICTORY_PANEL='1'}
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$NoSmoothMotion,
    [switch]$SeriesX,
    [switch]$Quality,
    [switch]$RayTracing,
    [ValidateSet('2160', '1440', '1080', '720', '540', '480')][string]$Resolution,
    [string]$Adapter,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [hashtable]$More = @{}
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'
    VICTORY_RELAY = '2'
    VICTORY_CARD_STEPS = '2'
    VICTORY_WIDE_BACK = '1'
    VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'
    VICTORY_INDIRECT_WINDOW = '1'
    VICTORY_RELAY_COPY = '1'
    VICTORY_INDIRECT_BATCH = '2'
    VICTORY_MAP_THREADS = '1'
    VICTORY_TITLE_PRIORITIES = '0'
    VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'
    VICTORY_AMBIENT = '0.8'
    VICTORY_D3D12_DRED = 'light'
    VICTORY_SKIP_PIPELINES = 'none'
    VICTORY_THIN = '1'
    VICTORY_THIN_THREADS = '8'
    VICTORY_JOIN_PARTS = '8'
    VICTORY_UPLOAD_AHEAD = '1'
    VICTORY_ASYNC_SUBMIT = '1'
    VICTORY_LEVELS_ON_DEMAND = '1'
    VICTORY_CARD_ROOM_FOR_BUFFERS = '1'
    VICTORY_CARD_WINDOWS_MB = '1024'
    VICTORY_WINDOWS_BAR_MB = '512'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
    VICTORY_AMBIENT_AIR = '1.5'
    VICTORY_AMBIENT_MOST = '2'
    VICTORY_NAN_SCRUB = '1'
    VICTORY_PIPELINE_WAIT_MS = '10000'
    VICTORY_PIPELINE_WAIT_ONCE = '1'
    VICTORY_DYNAMIC_SLOTS = '262144'
    VICTORY_RENDER_SCALE = '0.5'
    VICTORY_OWN_UPSCALER = '1'
    VICTORY_BVH_MISS = '1'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
    VICTORY_CARD_BUFFERS_MIN_MB = '1'
    VICTORY_CARD_BUFFERS_MB = '1024'
    VICTORY_CARD_WINDOWS_MB = '1024'
    VICTORY_WINDOWS_BAR_MB = '512'
    VICTORY_COMPOSE = '1'
    VICTORY_AMBIENT_AIR = '1.5'
    VICTORY_AMBIENT_MOST = '2'
    VICTORY_NAN_SCRUB = '1'
    VICTORY_PIPELINE_WAIT_MS = '10000'
    VICTORY_PIPELINE_WAIT_ONCE = '1'
    VICTORY_DYNAMIC_SLOTS = '262144'
    VICTORY_RENDER_SCALE = '0.5'
    VICTORY_OWN_UPSCALER = '1'
    VICTORY_BVH_MISS = '1'
}
# Ray tracing mostly off. The structure builder cannot run on NVIDIA (its 64-lane programs are refused; upstream
# Marvisak/VIctory pull request 2311), so every ray misses, and the passes that turn misses into light made rooms go
# white depending on the view angle. rt_off_hashes.txt lists the 1,000 CS_RaytracingResolve and 34 traced-shadow
# shaders, which are skipped. The screen-probe and visibility traces keep running: skipping those too left their
# outputs as garbage (rainbow glitter everywhere).
$rtList = Join-Path $PSScriptRoot 'rt_off_hashes.txt'
if (-not $RayTracing -and (Test-Path $rtList)) {
    $settings.VICTORY_SKIP_PIPELINES = (Get-Content $rtList -Raw).Trim()
}
if ($Quality) {
    # Stretched/jumping bodies: relay stage 1 and no card steps (avatarmanz/VIctory-7900XTX issue 13,
    # fxceless/victory-fork issue 89). Rainbow skin: texture refreshes wait for the runtime's remapping.
    # Costs about 7 fps (the submitting thread waits about 30 ms a frame for the card).
    $settings.VICTORY_RELAY = '1'
    $settings.VICTORY_CARD_STEPS = '0'
    $settings.VICTORY_TEXTURE_NO_WAIT = '0'
}
# The render scale is the rendered height over the output height (Series S 1080, Series X 2160).
$outHeight = if ($SeriesX) { 2160 } else { 1080 }
$console = if ($SeriesX) { 'X' } else { 'S' }
if ($Resolution) {
    if ([int]$Resolution -gt $outHeight) {
        Write-Host "Series $console outputs ${outHeight}p: ${Resolution}p is above it."
        return
    }
    $settings.VICTORY_RENDER_SCALE = ([int]$Resolution / $outHeight).ToString('0.####', [Globalization.CultureInfo]::InvariantCulture)
}
if ($Adapter) { $settings.VICTORY_ADAPTER = $Adapter }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }
$scale = [double]::Parse($settings.VICTORY_RENDER_SCALE, [Globalization.CultureInfo]::InvariantCulture)
Write-Host "Series $console, rendering at $([int]($outHeight * $scale))p (render scale $($settings.VICTORY_RENDER_SCALE))"

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; return }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; return }
if (-not $NoSmoothMotion) {
    $sm = Join-Path (Split-Path $victory) 'victory_sm.exe'
    if (-not (Test-Path $sm) -or (Get-Item $sm).LastWriteTime -lt (Get-Item $victory).LastWriteTime) {
        Copy-Item $victory $sm -Force
    }
    $victory = $sm
}
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$Exe = (Resolve-Path $Exe).Path
$runArgs = @('run', $Exe, '--execute')
if (-not $SeriesX) { $runArgs += @('--console', 'series-s') }
Push-Location (Join-Path $PSScriptRoot '..')
try { & $victory @runArgs } finally { Pop-Location }