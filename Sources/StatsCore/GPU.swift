import Foundation
import IOKit

public struct GPUUsage: Equatable, Sendable {
    /// Device utilisation, 0...1.
    public var utilization: Double
    /// Memory currently in use by the GPU driver, if reported.
    public var memoryInUse: UInt64?

    public init(utilization: Double, memoryInUse: UInt64?) {
        self.utilization = utilization
        self.memoryInUse = memoryInUse
    }

    /// Parses an IOAccelerator "PerformanceStatistics" dictionary.
    /// Apple Silicon reports "Device Utilization %"; Intel/AMD drivers use "GPU Activity(%)".
    public init?(performanceStatistics stats: [String: Any]) {
        let keys = ["Device Utilization %", "GPU Activity(%)"]
        guard let percent = keys.lazy.compactMap({ (stats[$0] as? NSNumber)?.doubleValue }).first
        else { return nil }
        self.utilization = min(1, max(0, percent / 100))
        self.memoryInUse = (stats["In use system memory"] as? NSNumber)?.uint64Value
    }
}

public final class GPUSampler {
    public init() {}

    /// Reads every IOAccelerator and reports the busiest one.
    public func sample() -> GPUUsage? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var best: GPUUsage?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard
                let prop = IORegistryEntryCreateCFProperty(
                    service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0),
                let stats = prop.takeRetainedValue() as? [String: Any],
                let usage = GPUUsage(performanceStatistics: stats)
            else { continue }
            if best == nil || usage.utilization > best!.utilization { best = usage }
        }
        return best
    }
}
