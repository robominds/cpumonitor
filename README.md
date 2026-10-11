# CPUMonitor

[![CI](https://github.com/robominds/cpumonitor/actions/workflows/ci.yml/badge.svg)](https://github.com/robominds/cpumonitor/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A small native macOS menu bar app that shows live **CPU**, **GPU** and **memory** usage.

```
CPU  12%  GPU   5%  MEM  63%
```

- Native AppKit and Swift, with no dependencies, helpers, kernel extensions or admin rights
- Low overhead: about 0.4% CPU and a ~23 MB memory footprint
- Memory "used" is calculated the same way as Activity Monitor
- Works on Apple Silicon and Intel Macs running macOS 13 Ventura or later

## Features

The menu bar shows compact labelled percentages. Digits are fixed-width, so the item doesn't shift as values change.

Click the item for a live breakdown and settings:

| Menu item | What it does |
|---|---|
| **CPU** | Total usage, split into user and system time |
| **GPU** | GPU utilisation and GPU memory in use |
| **MEM** | Used memory out of total, with app / wired / compressed breakdown |
| **Show in Menu Bar** | Choose which of CPU / GPU / MEM appear. With all three hidden, a gauge icon is shown instead |
| **Update Every** | 1, 2 or 5 seconds (default 2) |
| **Highlight High Usage** | Turns values orange at ≥75% and red at ≥90% |
| **Launch at Login** | Registers the app as a login item (requires the bundled `.app`) |
| **Open Activity Monitor** | Opens Activity Monitor for per-process detail |

Settings are saved in `UserDefaults` under `com.markcastelluccio.cpumonitor`.

## Install

Requires Xcode (or the Swift toolchain) with Swift 5.10 or later.

```sh
git clone https://github.com/robominds/cpumonitor.git
cd cpumonitor
scripts/bundle.sh --install
```

This builds a universal (arm64 + x86_64), ad-hoc-signed `build/CPUMonitor.app`, copies it to `/Applications` and launches it. Run `scripts/bundle.sh` without `--install` to build the app only.

To uninstall, choose **Quit CPUMonitor** from its menu, turn off Launch at Login first if you enabled it, then delete `/Applications/CPUMonitor.app`.

## Development

```sh
swift build                 # debug build
swift run CPUMonitor        # run from the terminal (Ctrl-C to stop)
swift test                  # unit tests
```

Project layout:

```
Sources/
  StatsCore/        Metric sampling and formatting (no UI, unit-tested)
    CPU.swift       host_statistics(HOST_CPU_LOAD_INFO) tick deltas
    GPU.swift       IOAccelerator "PerformanceStatistics"
    Memory.swift    host_statistics64(HOST_VM_INFO64)
    Format.swift    Fixed-width percent and GB formatting
  CPUMonitor/       AppKit status item, menu and settings
Tests/StatsCoreTests/
scripts/bundle.sh   Builds and signs CPUMonitor.app
docs/               How the metrics are measured
```

For how each number is calculated, see [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md).

## FAQ

**Why does Activity Monitor show more memory for CPUMonitor than the footprint above?**
Tools that report *resident size* (RSS), such as `ps` and `top`, count shared system framework pages (AppKit, CoreGraphics and so on) that are mapped into every app. Those pages aren't extra memory used by CPUMonitor. The meaningful number is the *physical footprint*, which you can check with `footprint -p $(pgrep -x CPUMonitor)`. It is about 23 MB, most of which is AppKit's baseline for any app that draws UI.

**GPU shows "–" or "unavailable".**
The GPU driver didn't publish utilisation statistics. This can happen with some older Intel or AMD GPUs and in virtual machines.

**Launch at Login shows an error.**
Launch at Login only works from the bundled app. Use `scripts/bundle.sh --install` rather than `swift run`.

## License

[MIT](LICENSE) © 2026 Mark Castelluccio

## Authorship

Created by Mark Castelluccio. Code and documentation were written with the help of Claude (Anthropic's AI assistant) using Claude Code.
