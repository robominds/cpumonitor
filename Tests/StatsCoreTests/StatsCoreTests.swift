import XCTest
@testable import StatsCore

final class CPUUsageTests: XCTestCase {
    func testComputesFractionsFromDeltas() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
        let b = CPUTicks(user: 130, system: 60, idle: 860, nice: 10)
        let u = CPUUsage(from: a, to: b)
        // deltas: user 30 + nice 10 = 40, system 10, idle 60, sum 110
        XCTAssertEqual(u.user, 40.0 / 110, accuracy: 1e-9)
        XCTAssertEqual(u.system, 10.0 / 110, accuracy: 1e-9)
        XCTAssertEqual(u.total, 50.0 / 110, accuracy: 1e-9)
    }

    func testHandlesCounterWraparound() {
        let a = CPUTicks(user: UInt32.max - 9, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)
        let u = CPUUsage(from: a, to: b)
        XCTAssertEqual(u.user, 0.5, accuracy: 1e-9)  // 20 user, 20 idle
    }

    func testZeroDeltaIsIdle() {
        let t = CPUTicks(user: 1, system: 1, idle: 1, nice: 1)
        XCTAssertEqual(CPUUsage(from: t, to: t).total, 0)
    }

    func testLiveSamplerReturnsSaneValue() throws {
        let s = CPUSampler()
        Thread.sleep(forTimeInterval: 0.2)
        let u = try XCTUnwrap(s.sample())
        XCTAssert((0...1).contains(u.total))
    }
}

final class MemoryUsageTests: XCTestCase {
    func testActivityMonitorFormula() {
        let m = MemoryUsage(
            total: 16 * 1024, pageSize: 16,
            internalPages: 300, purgeablePages: 50, externalPages: 100,
            wiredPages: 100, compressorPages: 50)
        XCTAssertEqual(m.app, 250 * 16)
        XCTAssertEqual(m.used, (250 + 100 + 50) * 16)
        XCTAssertEqual(m.cached, 150 * 16)
        XCTAssertEqual(m.fraction, 400.0 / 1024, accuracy: 1e-9)
    }

    func testPurgeableLargerThanInternalClampsToZero() {
        let m = MemoryUsage(
            total: 1000, pageSize: 1, internalPages: 5, purgeablePages: 10,
            externalPages: 0, wiredPages: 0, compressorPages: 0)
        XCTAssertEqual(m.app, 0)
    }

    func testLiveSamplerReturnsSaneValue() throws {
        let m = try XCTUnwrap(MemorySampler().sample())
        XCTAssertGreaterThan(m.used, 0)
        XCTAssertLessThanOrEqual(m.used, m.total)
    }
}

final class GPUUsageTests: XCTestCase {
    func testParsesAppleSiliconKey() {
        let g = GPUUsage(performanceStatistics: ["Device Utilization %": 42, "In use system memory": 1024])
        XCTAssertEqual(g?.utilization ?? -1, 0.42, accuracy: 1e-9)
        XCTAssertEqual(g?.memoryInUse, 1024)
    }

    func testParsesIntelKey() {
        let g = GPUUsage(performanceStatistics: ["GPU Activity(%)": 7])
        XCTAssertEqual(g?.utilization ?? -1, 0.07, accuracy: 1e-9)
        XCTAssertNil(g?.memoryInUse)
    }

    func testMissingKeyIsNil() {
        XCTAssertNil(GPUUsage(performanceStatistics: ["Tiler Utilization %": 3]))
    }
}

final class FormatTests: XCTestCase {
    let fs = "\u{2007}"

    func testPercentPadsToThreeDigits() {
        XCTAssertEqual(Format.percent(0.07), "\(fs)\(fs)7%")
        XCTAssertEqual(Format.percent(0.456), "\(fs)46%")
        XCTAssertEqual(Format.percent(1), "100%")
    }

    func testPercentClampsAndHandlesNil() {
        XCTAssertEqual(Format.percent(1.7), "100%")
        XCTAssertEqual(Format.percent(-0.2), "\(fs)\(fs)0%")
        XCTAssertEqual(Format.percent(nil), "\(fs)–\(fs)%")
    }

    func testGigabytes() {
        XCTAssertEqual(Format.gigabytes(3 * 1_073_741_824 / 2), "1.5 GB")
    }
}
