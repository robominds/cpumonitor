import Darwin

/// Cumulative CPU tick counters across all cores, as reported by the Mach kernel.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// CPU utilisation over an interval, each component in 0...1.
public struct CPUUsage: Equatable, Sendable {
    public var user: Double
    public var system: Double
    public var idle: Double

    public var total: Double { user + system }

    /// Computes usage between two tick snapshots. Counters are 32-bit and may
    /// wrap, so deltas use wrapping subtraction.
    public init(from a: CPUTicks, to b: CPUTicks) {
        let user = Double(b.user &- a.user) + Double(b.nice &- a.nice)
        let system = Double(b.system &- a.system)
        let idle = Double(b.idle &- a.idle)
        let sum = user + system + idle
        guard sum > 0 else {
            self.user = 0; self.system = 0; self.idle = 1
            return
        }
        self.user = user / sum
        self.system = system / sum
        self.idle = idle / sum
    }
}

public final class CPUSampler {
    private let host = mach_host_self()
    private var previous: CPUTicks?

    public init() {
        previous = Self.readTicks(host)
    }

    /// Returns usage since the previous call (or since init).
    public func sample() -> CPUUsage? {
        guard let now = Self.readTicks(host) else { return nil }
        defer { previous = now }
        guard let prev = previous else { return nil }
        return CPUUsage(from: prev, to: now)
    }

    static func readTicks(_ host: host_t) -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let t = info.cpu_ticks  // (user, system, idle, nice)
        return CPUTicks(user: t.0, system: t.1, idle: t.2, nice: t.3)
    }
}
