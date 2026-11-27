# GTA VI on RTX 5060 8GB - Quick Start Guide

## Hardware Requirements Met ✓
- **CPU**: Intel Core Ultra 7 265K (Arrow Lake, AVX2+) ✓
- **RAM**: 32GB DDR5 ✓ (32GB+ recommended)
- **GPU**: RTX 5060 8GB VRAM ✓ (Wave32, SM 6.6, Mesh Shaders)
- **OS**: Windows 11 ✓

---

## Prerequisites (Install Once)

### 1. Rust Toolchain
```powershell
# Install rustup from https://rustup.rs/
# Then install the pinned toolchain (each repo has rust-toolchain.toml)
rustup update stable-msvc
```

### 2. Visual Studio 2022
- Install **Visual Studio 2022 Community** (free)
- Workload: **Desktop development with C++**
- Includes: MSVC v143, CMake, Windows SDK 10.0.26100+

### 3. DXC 1.8+ (Critical for Shader Compilation)
```powershell
# Download from: https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2502
# Extract to: C:\Tools\DXC
# Add to PATH or set XCL_DXC_DIR=C:\Tools\DXC\bin\x64
```

### 4. Game Files
You need the **Xbox Series X|S dump** (unpacked game files):
- Folder containing `title.exe` (or similar executable)
- `shaders.rpf` archive
- Other game assets

---

## Step 1: Configure Paths

### For victory-nvidia-8gb (BEST for 8GB VRAM):
```powershell
cd "GTA6-Build\victory-nvidia-8gb"
copy victory.toml.template victory.toml
notepad victory.toml
```

**Edit these REQUIRED fields in victory.toml:**
```toml
game_dir = "D:\Your\Game\Dump\Path"      # Folder with title.exe
shader_archives = ["D:\Your\Game\Dump\shaders.rpf"]
data_dir = "D:\Your\Data\Path"            # Will be created
cache_dir = "D:\Your\Cache\Path"          # Will be created
```

### For VIctory-NVIDIA (Series S Half-Scale - Higher FPS):
```powershell
cd "GTA6-Build\VIctory-NVIDIA"
copy victory.toml.template victory.toml
notepad victory.toml
```

---

## Step 2: Build

### Option A: victory-nvidia-8gb (Recommended for 8GB VRAM)
```powershell
cd "GTA6-Build\victory-nvidia-8gb"
cargo build --release --bin victory
# Takes 5-15 minutes
# Output: target\release\victory.exe
```

### Option B: VIctory-NVIDIA (Series S Half-Scale ~18-22 FPS)
```powershell
cd "GTA6-Build\VIctory-NVIDIA"
cargo build --locked --profile diag -p victory --features diagnostics
# Takes 10-20 minutes
# Output: target\diag\victory.exe
```

---

## Step 3: Precompile Shaders (Optional but Recommended)
```powershell
# For victory-nvidia-8gb
.\target\release\victory.exe shaders D:\Your\Game\Dump\shaders.rpf --warm all --jobs 16
.\target\release\victory.exe warm --used

# For VIctory-NVIDIA
.\target\diag\victory.exe shaders D:\Your\Game\Dump\shaders.rpf --warm all --jobs 16
.\target\diag\victory.exe warm --used
```
**Takes 5-15 minutes.** Creates pipeline cache so first run doesn't stutter.

---

## Step 4: Run

### victory-nvidia-8gb (Native ~6-10 FPS, Full Series X Visuals)
```powershell
cd "GTA6-Build\victory-nvidia-8gb"
.\scripts\play-nvidia-8gb.ps1 -Exe "D:\Your\Game\Dump\title.exe"
```
**Settings auto-applied:**
- `VICTORY_TEXTURE_DROP_MIPS=2` - Fits in 8GB VRAM
- `VICTORY_RESOLUTION=1920x1080` - Caps GPU load
- `VICTORY_COPY_PLAIN=1` - Faster memory copies
- `VICTORY_WINDOW_PERCENT=88` - Fixes black window bug
- **Press F10** for performance overlay

---

### VIctory-NVIDIA (Series S Half-Scale ~18-22 FPS Native)
```powershell
cd "GTA6-Build\VIctory-NVIDIA"
.\scripts\play-nvidia.ps1 -Exe "D:\Your\Game\Dump\title.exe"
```
**Settings auto-applied:**
- `--console series-s` - Smaller console profile
- `VICTORY_RENDER_SCALE=0.5` - World at 960x540 → upscaled to 1080p
- `VICTORY_OWN_UPSCALER=1` - Game's temporal upscaler
- `VICTORY_BVH_MISS=1` - Skip ray-tracing (saves ~10ms/frame)
- `VICTORY_CARD_BUFFERS_MB=1536` - GPU memory compares (2x FPS)
- `VICTORY_DYNAMIC_SLOTS=524288` - Fixes NVIDIA descriptor heap cap
- **NVIDIA Smooth Motion** - Enable in NVIDIA App for 2x perceived smoothness

**Resolution options:**
```powershell
# 540p (default, fastest) - 960x540 world
.\scripts\play-S-540p.ps1 -Exe "..."

# 720p - 1280x720 world
.\scripts\play-S-720p.ps1 -Exe "..."

# Quality mode (fewer artifacts, ~7 FPS less)
.\scripts\play-nvidia.ps1 -Exe "..." -Quality
```

---

## Step 5: Enable NVIDIA Smooth Motion (VIctory-NVIDIA Only)
1. Open **NVIDIA App** (new control panel)
2. Go to **Graphics → Program Settings**
3. Add `victory_sm.exe` (from `target\diag\`)
4. Enable **Smooth Motion**
5. The launcher auto-uses this exe

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| **Black window** | Set `VICTORY_WINDOW_PERCENT=88` or `-Borderless` |
| **Crash at startup (1455)** | Increase Windows page file or close apps |
| **Shader compile timeout** | Increase `VICTORY_PIPELINE_WAIT_MS=20000` |
| **Device lost / driver reset** | Use `VICTORY_D3D12_WARP=1` for software rendering test |
| **Out of VRAM** | Ensure `VICTORY_TEXTURE_DROP_MIPS=2` is set |
| **Faces don't move** | Fixed in VIctory-NVIDIA (integer face network) |

---

## Expected Performance (RTX 5060 8GB)

| Build | Mode | Expected FPS | Visual Quality |
|-------|------|--------------|----------------|
| victory-nvidia-8gb | Series X 1080p | 6-10 FPS | Full lighting, sharp |
| VIctory-NVIDIA | Series S 540p | 18-22 FPS | Half-scale, upscaled |
| VIctory-NVIDIA | Series S 540p + Smooth Motion | 18-22 FPS (feels 36-44) | Half-scale, upscaled |

---

## Controls
- **Gamepad**: XInput (Xbox controller) - Recommended
- **Keyboard/Mouse** (no gamepad):
  - WASD / IJKL = Left/Right stick
  - Arrows = D-pad
  - Enter/Backspace/X/Y = A/B/X/Y
  - Q/E, Z/C = Shoulders/Triggers
  - F/H = Stick clicks
  - Esc/Tab = Menu/View

---

## Useful Commands
```powershell
# Check config
.\target\release\victory.exe config

# Translate specific shader
.\target\release\victory.exe translate shader.bin --validate

# Capture frame (diagnostics build)
$env:VICTORY_CAPTURE="D:\Captures"; .\target\diag\victory.exe run ...

# Enable debug logging
$env:VICTORY_LOG="victory_loader=trace,victory_gpu=debug"
```

---

## Support & Community
- **VIctory Discord**: https://discord.gg/victory
- **XCL Discord**: https://discord.gg/xcl
- **Xbox2Windows Discord**: https://discord.gg/DMcmNtpd6R
- **GTA VI PC Race Tracker**: https://vuyp.github.io/gta6-pc-race/
- **gta6recomp.com**: https://gta6recomp.com/repo

---

## Legal Notice
This software runs game files you own. It does not include game files, keys, or DRM circumvention. Licensed GPL-3.0-or-later.