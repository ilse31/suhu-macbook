import Foundation

public enum Metrics {
    public static func temperature(type: String, bytes: [UInt8]) -> Double? {
        let value: Double
        switch type {
        case "sp78" where bytes.count >= 2:
            value = Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "flt " where bytes.count >= 4:
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            value = Double(Float(bitPattern: bits))
        default: return nil
        }
        return value.isFinite && value > 0 && value < 150 ? value : nil
    }

    public static func cpuUsage(previous: [UInt32], current: [UInt32]) -> Double? {
        guard previous.count == 4, current.count == 4 else { return nil }
        let delta = zip(current, previous).map { UInt64($0 &- $1) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(total - delta[2]) / Double(total) * 100
    }
}
