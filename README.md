# 13 Years Later

> A compatibility layer for running a specific Xbox Series X|S title on Windows.

## Overview

This project implements a native translation layer that executes the console executable directly on Windows, translating Direct3D 12 commands and system calls at runtime. No CPU emulation is involved — the game's x86-64 code runs natively.

## Current Status

| Milestone | Progress |
|-----------|----------|
| Executable loading | ✓ Complete |
| System call translation | ✓ Complete |
| Swapchain presentation | ✓ Complete |
| First frames | ✓ Complete |
| Main menu & intro | ✓ ~30 FPS |
| In-game (3D world) | 🟡 Partial |
| Shaders & lighting | 🟡 Work in progress |
| Playable framerate | 🟡 Targeting 20+ FPS |

## Technical Approach

- **Runtime translation**: Direct3D 12 command recording → host GPU submission
- **Memory management**: Custom allocators with VRAM budgeting for 8 GB cards
- **Shader pipeline**: On-demand DXIL → SPIR-V → native translation with caching
- **System layer**: HLE (High-Level Emulation) of console OS services
- **Threading**: Async submit with multi-queue synchronization

## Supported Hardware

| GPU | VRAM | Profile | Typical FPS |
|-----|------|---------|-------------|
| RTX 5070 / 5060 Ti | 12 / 8 GB | Smaller console (half-scale) | 20–22 |
| RTX 4070 / 4060 | 12 / 8 GB | Smaller console (half-scale) | 15–18 |
| RX 7900 XTX | 24 GB | Larger console | 19–22 |

> **Note**: "Smaller console profile" = Series S equivalent render target; "Larger console profile" = Series X equivalent.

### Tested Configuration (Author's Hardware)

| Component | Specification |
|-----------|---------------|
| **CPU** | Intel Core Ultra 7 265K (Arrow Lake, AVX2+) |
| **RAM** | 32 GB DDR5 |
| **GPU** | NVIDIA RTX 5060 8 GB (Wave32, SM 6.6, Mesh Shaders) |
| **OS** | Windows 11 |

**Achieved Performance:**

| Build | Mode | Achieved FPS | Notes |
|-------|------|--------------|-------|
| VIctory-NVIDIA | Series S 540p (half-scale) | **7–10 FPS** | Lower than expected 18–22 FPS; may need driver/optimization tuning |

> **Note**: Series S half-scale mode runs at 960×540 rendered → upscaled to 1080p via game's temporal upscaler. The 7–10 FPS on RTX 5060 8GB suggests VRAM pressure or driver overhead; `VICTORY_TEXTURE_DROP_MIPS=2` and `VICTORY_RENDER_SCALE=0.5` are critical. Other modes (Smooth Motion, Series X) not yet tested.

## Building

```bash
# Requires: Rust 1.80+, Windows 10/11 SDK, Visual Studio 2022
cargo build --release --features nvidia
```

## Running

```bash
# Place the console executable in ./game/
# Configure adapter selection in config.toml
./target/release/launcher.exe
```

## Configuration

Key settings in `config.toml`:

```toml
[gpu]
adapter_preference = "nvidia"  # or "amd"
render_scale = 0.5             # 0.5 = half-scale (Series S profile)
vram_budget_mb = 5500          # Leave headroom for OS

[shader]
cache_dir = "./shader-cache"
parallel_jobs = 12
warm_on_startup = true

[hle]
mouse_camera = true
controller_passthrough = true
```

## Milestones

- [x] Executable loads to main menu
- [x] Intro cinematic plays at 30 FPS
- [x] First in-game frames rendered
- [ ] Stable 20+ FPS in opening mission
- [ ] Full lighting pipeline (ray-traced shadows, GI)
- [ ] 30 FPS sustained gameplay
- [ ] Complete story mode playthrough

## License

GPL-3.0-or-later — see [LICENSE](LICENSE) for details.

## Disclaimer

This is a research/educational project for studying console-to-PC translation techniques. It does not include any game assets, encryption keys, or copyrighted content. You must provide your own legally obtained console build.