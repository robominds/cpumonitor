import Darwin
import Foundation

/// Memory figures in bytes, computed the same way Activity Monitor does.
public struct MemoryUsage: Equatable, Sendable {
    public var total: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64

    /// "Memory Used" in Activity Monitor: app + wired + compressed.
    public var used: UInt64 { app + wired + compressed }
    public var fraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }

    public init(total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
    }

    /// Builds usage from raw page counts.
    public init(
        total: UInt64, pageSize: UInt64,
        internalPages: UInt64, purgeablePages: UInt64, externalPages: UInt64,
        wiredPages: UInt64, compressorPages: UInt64
    ) {
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        self.init(
            total: total,
            app: appPages * pageSize,
            wired: wiredPages * pageSize,
            compressed: compressorPages * pageSize,
            cached: (externalPages + purgeablePages) * pageSize)
    }
}

public final class MemorySampler {
    private let host = mach_host_self()
    private let pageSize: UInt64
    private let total = ProcessInfo.processInfo.physicalMemory

    public init() {
        var size: vm_size_t = 0
        host_page_size(host, &size)
        pageSize = UInt64(size)
    }

    public func sample() -> MemoryUsage? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return MemoryUsage(
            total: total, pageSize: pageSize,
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            externalPages: UInt64(stats.external_page_count),
            wiredPages: UInt64(stats.wire_count),
            compressorPages: UInt64(stats.compressor_page_count))
    }
}
