import Foundation
import Darwin
import CSMC

public struct Capacity: Codable {
    public let used: UInt64
    public let total: UInt64
    public var available: UInt64 { total - used }
    public var fraction: Double { total == 0 ? 0 : Double(used) / Double(total) }

    init(used: UInt64, total: UInt64) {
        self.total = total
        self.used = min(used, total)
    }
}

public struct TemperatureSensor: Codable {
    public let key: String
    public let celsius: Double
}

public struct Snapshot: Codable {
    public let sampledAt: Date
    public let cpuPercent: Double?
    public let memory: Capacity?
    public let memoryPressure: String?
    public let storage: Capacity?
    public let sensors: [TemperatureSensor]
    public let thermalState: String
    public var cpuTemperature: Double? { sensors.map(\.celsius).max() }
}

// One sampler belongs to one serial queue; it keeps the previous CPU counters.
public final class SystemSampler {
    private var connection: UInt32 = 0
    private var previousCPU: [UInt32]?
    private let host = mach_host_self()
    public let chipName: String

    public init() {
        var length = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &length, nil, 0)
        var name = [CChar](repeating: 0, count: max(length, 1))
        if sysctlbyname("machdep.cpu.brand_string", &name, &length, nil, 0) == 0 {
            chipName = String(cString: name)
        } else {
            chipName = "Mac"
        }
    }

    deinit {
        suhu_smc_close(connection)
        mach_port_deallocate(mach_task_self_, host)
    }

    public func sample() -> Snapshot {
        Snapshot(sampledAt: Date(), cpuPercent: readCPU(), memory: readMemory(),
                 memoryPressure: readMemoryPressure(), storage: readStorage(),
                 sensors: readTemperatures(), thermalState: thermalState)
    }

    private func readCPU() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { previousCPU = nil; return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        defer { previousCPU = ticks }
        guard let previousCPU else { return nil }
        return Metrics.cpuUsage(previous: previousCPU, current: ticks)
    }

    private func readMemory() -> Capacity? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pages = Int64(info.active_count) + Int64(info.inactive_count)
            + Int64(info.speculative_count) + Int64(info.wire_count)
            + Int64(info.compressor_page_count) - Int64(info.purgeable_count)
            - Int64(info.external_page_count)
        return Capacity(used: UInt64(max(0, pages)) * UInt64(vm_page_size),
                        total: ProcessInfo.processInfo.physicalMemory)
    }

    private func readMemoryPressure() -> String? {
        var level: Int32 = 0
        var length = MemoryLayout.size(ofValue: level)
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &length, nil, 0) == 0 else { return nil }
        switch level {
        case 1: return "Normal"
        case 2: return "Meningkat"
        case 4: return "Tinggi"
        default: return nil
        }
    }

    private func readStorage() -> Capacity? {
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = (values[.systemSize] as? NSNumber)?.uint64Value,
              let free = (values[.systemFreeSize] as? NSNumber)?.uint64Value,
              total > 0, free <= total else { return nil }
        return Capacity(used: total - free, total: total)
    }

    private func readTemperatures() -> [TemperatureSensor] {
        if connection == 0 { connection = suhu_smc_open() }
        guard connection != 0 else { return [] }
        let keys: [String]
        if chipName.contains("Apple M2") {
            keys = ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        } else if chipName.contains("Apple M1") {
            keys = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        } else {
            // shortcut: M1/M2 and Intel keys only; add a verified key map for newer chips.
            keys = ["TC0P"]
        }
        var sensors: [TemperatureSensor] = []
        for key in keys {
            var type: UInt32 = 0
            var length: UInt32 = 0
            var bytes = [UInt8](repeating: 0, count: 32)
            let success = suhu_smc_read(connection, key, &type, &bytes, &length)
            guard success != 0 else { continue }
            let typeName = String(bytes: [UInt8((type >> 24) & 255), UInt8((type >> 16) & 255),
                                          UInt8((type >> 8) & 255), UInt8(type & 255)], encoding: .ascii) ?? ""
            if let value = Metrics.temperature(type: typeName, bytes: Array(bytes.prefix(Int(length)))) {
                sensors.append(TemperatureSensor(key: key, celsius: value))
            }
        }
        if sensors.isEmpty {
            suhu_smc_close(connection)
            connection = 0
        }
        return sensors
    }

    private var thermalState: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Hangat"
        case .serious: return "Panas"
        case .critical: return "Kritis"
        @unknown default: return "Tidak diketahui"
        }
    }
}
