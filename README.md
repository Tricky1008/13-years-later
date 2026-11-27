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

## Credits

This configuration wraps and integrates work from the following upstream projects:

### VIctory-NVIDIA Configuration (`GTA6-Build\VIctory-NVIDIA`)
Built from multiple forks combined:

- **[avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)** — Threading, write relay, card fills, copy queue, texture read-back
- **[Marvisak/VIctory](https://github.com/Marvisak/VIctory)** — Original compatibility layer (loader, runtime services, D3D12 backend, shader recompiler)
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)** (formerly victory-gta6) — Series S interface plane (PR [#1189](https://github.com/fxceless/victory-fork/pull/1189), Tissma95), face network fix (PR [#927](https://github.com/fxceless/victory-fork/pull/927), tippythetaidum)
- **[victory-perf](https://github.com/ZigZagBoi1/ScarlettPort)** (from ZigZagBoi1/ScarlettPort) — Render scale patches, own upscaler, watchdog
- Through the 7900 XTX fork: **[DexNom/VIctory](https://github.com/DexNom/VIctory)**, **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)**, **[FQY55kai/ZJOU-VICTORY](https://github.com/FQY55kai/ZJOU-VICTORY)**, **[myokex/victory-amd](https://github.com/myokex/victory-amd)**, Geckomacabre, cxy0072019-sketch

Projects studied but code not directly included: **[ProjectLeonida/Leonida](https://github.com/ProjectLeonida/Leonida)**, **[Belobug builds](https://github.com/Belobug/VIctory-Belobug-AMD)**, **[zm0kiemedia/Neptune_VI](https://github.com/zm0kiemedia/Neptune_VI)**, **[xcl-dev/xcl](https://github.com/xcl-dev/xcl)**

### victory-nvidia-8gb Configuration (`GTA6-Build\victory-nvidia-8gb`)
Fork of **[fxceless/victory-fork@f5c03f3](https://github.com/fxceless/victory-fork/tree/f5c03f3)** (itself a fork of Marvisak/VIctory), tuned for 8 GB NVIDIA GPUs (Wave32). Integrates PRs from:

- **[soldsawn/victory-nvidia-8gb#1](https://github.com/soldsawn/victory-nvidia-8gb/pull/1)** (DKTTT) — `VICTORY_RESOLUTION=1920x1080`, `VICTORY_BORDERLESS=1`, `VICTORY_WINDOW_PERCENT`
- **[zm0kiemedia/Neptune_VI](https://github.com/zm0kiemedia/Neptune_VI)** (Traffic & zm0kie) — Translucent performance overlay (`soldsawn 8GB` with F10 toggle)
- **[Marvisak/VIctory#1009](https://github.com/Marvisak/VIctory/pull/1009)** — `xmem::low_guards` for >32 GB RAM
- **fxceless/victory-fork PRs**: [#610](https://github.com/fxceless/victory-fork/pull/610), [#799](https://github.com/fxceless/victory-fork/pull/799), [#854](https://github.com/fxceless/victory-fork/pull/854), [#868](https://github.com/fxceless/victory-fork/pull/868), [#812](https://github.com/fxceless/victory-fork/pull/812), [#979](https://github.com/fxceless/victory-fork/pull/979), [#987](https://github.com/fxceless/victory-fork/pull/987), [#768](https://github.com/fxceless/victory-fork/pull/768), [#864](https://github.com/fxceless/victory-fork/pull/864), [#860](https://github.com/fxceless/victory-fork/pull/860), [#936](https://github.com/fxceless/victory-fork/pull/936), [#432](https://github.com/fxceless/victory-fork/pull/432), [#932](https://github.com/fxceless/victory-fork/pull/932), [#922](https://github.com/fxceless/victory-fork/pull/922), [#896](https://github.com/fxceless/victory-fork/pull/896), [#964](https://github.com/fxceless/victory-fork/pull/964), [#853](https://github.com/fxceless/victory-fork/pull/853), [#231](https://github.com/fxceless/victory-fork/pull/231), [#71](https://github.com/fxceless/victory-fork/pull/71), [#798](https://github.com/fxceless/victory-fork/pull/798), [#188](https://github.com/fxceless/victory-fork/pull/188), [#144](https://github.com/fxceless/victory-fork/pull/144), [#949](https://github.com/fxceless/victory-fork/pull/949), [#1007](https://github.com/fxceless/victory-fork/pull/1007), [#1015](https://github.com/fxceless/victory-fork/pull/1015), [#1029](https://github.com/fxceless/victory-fork/pull/1029), [#1032](https://github.com/fxceless/victory-fork/pull/1032), [#1043](https://github.com/fxceless/victory-fork/pull/1043), [#1044](https://github.com/fxceless/victory-fork/pull/1044), [#1069](https://github.com/fxceless/victory-fork/pull/1069), [#1086](https://github.com/fxceless/victory-fork/pull/1086), [#1093](https://github.com/fxceless/victory-fork/pull/1093), [#1117](https://github.com/fxceless/victory-fork/pull/1117), [#1120](https://github.com/fxceless/victory-fork/pull/1120), [#1122](https://github.com/fxceless/victory-fork/pull/1122), [#1128](https://github.com/fxceless/victory-fork/pull/1128), [#999](https://github.com/fxceless/victory-fork/pull/999)

### Xbox2Windows (`GTA6-Build\Xbox2Windows`)
Static recompilation research by **[R0Y00/Xbox2Windows](https://github.com/R0Y00/Xbox2Windows)** — Translates x64 Xbox Series X\|S code to C++ and gfx1013 shaders to desktop DXIL. Not a full emulator/playable port.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE) for details.

## Disclaimer

This is a research/educational project for studying console-to-PC translation techniques. It does not include any game assets, encryption keys, or copyrighted content. You must provide your own legally obtained console build.