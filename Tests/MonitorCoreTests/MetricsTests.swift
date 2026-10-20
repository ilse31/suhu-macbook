import XCTest
import CSMC
@testable import MonitorCore

final class MetricsTests: XCTestCase {
    func testTemperatureDecodesSMCFixedPointAndLittleEndianFloat() {
        XCTAssertEqual(Metrics.temperature(type: "sp78", bytes: [0x32, 0x80]), 50.5)
        XCTAssertEqual(Metrics.temperature(type: "flt ", bytes: [0, 0, 0x4A, 0x42]), 50.5)
    }

    func testUnavailableOrInvalidSensorsNeverBecomeZeroDegrees() {
        for (type, bytes): (String, [UInt8]) in [
            ("flt ", []), ("sp78", [0]), ("ui32", [0, 0, 0, 50]),
            ("flt ", [0, 0, 0xC0, 0x7F]), ("sp78", [0, 0]), ("sp78", [0xFF, 0])
        ] {
            XCTAssertNil(Metrics.temperature(type: type, bytes: bytes))
        }
    }

    func testCPUUsesIntervalAcrossAllModesAndHandlesCounterWrap() {
        // Mach order: user, system, idle, nice. Half of the interval is busy.
        XCTAssertEqual(Metrics.cpuUsage(previous: [10, 10, 20, 0], current: [20, 15, 40, 5]), 50)
        XCTAssertEqual(Metrics.cpuUsage(previous: [UInt32.max - 4, 0, 0, 0], current: [5, 0, 10, 0]), 50)
    }

    func testNoCPUIntervalIsUnavailable() {
        XCTAssertNil(Metrics.cpuUsage(previous: [0, 0, 0, 0], current: [0, 0, 0, 0]))
        XCTAssertNil(Metrics.cpuUsage(previous: [], current: [1, 2, 3, 4]))
    }

    func testCapacityCannotExposeNegativeAvailableSpace() {
        let capacity = Capacity(used: 200, total: 100)
        XCTAssertEqual(capacity.used, 100)
        XCTAssertEqual(capacity.available, 0)
        XCTAssertEqual(capacity.fraction, 1)
        XCTAssertEqual(Capacity(used: 0, total: 0).fraction, 0)
    }

    func testFailedSMCReadClearsOutputInsteadOfReusingStaleTemperature() {
        var type: UInt32 = 42
        var length: UInt32 = 4
        var bytes = [UInt8](repeating: 255, count: 32)
        XCTAssertEqual(suhu_smc_read(0, "Tp01", &type, &bytes, &length), 0)
        XCTAssertEqual(type, 0)
        XCTAssertEqual(length, 0)
        XCTAssertEqual(bytes, [UInt8](repeating: 0, count: 32))
    }

    func testLiveSamplerReadsCPUPhysicalMemoryAndHomeVolume() throws {
        let sampler = SystemSampler()
        let first = sampler.sample()
        XCTAssertNil(first.cpuPercent)
        Thread.sleep(forTimeInterval: 0.1)
        let snapshot = sampler.sample()
        let cpu = try XCTUnwrap(snapshot.cpuPercent)
        XCTAssertTrue((0...100).contains(cpu))
        let memory = try XCTUnwrap(snapshot.memory)
        XCTAssertEqual(memory.total, ProcessInfo.processInfo.physicalMemory)
        XCTAssertGreaterThan(memory.used, 0)
        XCTAssertLessThanOrEqual(memory.used, memory.total)
        let disk = try XCTUnwrap(snapshot.storage)
        XCTAssertGreaterThan(disk.total, 0)
        XCTAssertLessThanOrEqual(disk.used, disk.total)
    }
}
