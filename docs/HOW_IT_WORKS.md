# How CPUMonitor measures things

CPUMonitor uses only public, unprivileged macOS APIs. Each refresh runs three samplers from `Sources/StatsCore` on the main run loop. The default interval is 2 s. The timer is added in `.common` mode, so the values keep updating while the menu is open.

## CPU — `CPU.swift`

`host_statistics(HOST_CPU_LOAD_INFO)` returns cumulative tick counters summed across all cores: user, system, idle and nice. Utilisation is calculated from the change between two samples:

```
user   = Δuser + Δnice
system = Δsystem
total  = (user + system) / (user + system + Δidle)
```

The counters are 32-bit and wrap around, so deltas use wrapping subtraction (`&-`). The first sample is taken at launch, so the first reading covers the time since startup. After that, each reading covers one interval.

## GPU — `GPU.swift`

The sampler walks every `IOAccelerator` service in the IORegistry and reads its `PerformanceStatistics` dictionary:

- **Apple Silicon:** `Device Utilization %`
- **Intel / AMD:** `GPU Activity(%)`

If there is more than one GPU, the busiest one is shown. `In use system memory` is shown in the menu when it's present. You can see the raw data with:

```sh
ioreg -r -c IOAccelerator -d 1 | grep PerformanceStatistics
```

## Memory — `Memory.swift`

`host_statistics64(HOST_VM_INFO64)` provides page counts, and `host_page_size` provides the page size (16 KB on Apple Silicon). "Used" follows the same formula as Activity Monitor:

```
app        = internal_page_count − purgeable_count
wired      = wire_count
compressed = compressor_page_count
used       = app + wired + compressed
percent    = used / hw.memsize
```

File-backed cache and purgeable memory count as *cached*, not *used*, because macOS reclaims them when memory is needed.

## Display — `Format.swift`, `AppDelegate.swift`

Percentages are padded to three digits with U+2007 FIGURE SPACE. That character is the same width as a digit in the monospaced-digit system font, so the status item stays the same width as values change. The labels use a smaller, secondary-coloured font. When highlighting is on, a value turns orange at ≥75% and red at ≥90%.
