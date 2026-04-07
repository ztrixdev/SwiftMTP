import Foundation

/// USB protocol versions exposed by connected devices.
enum USBProtocol: String, CustomStringConvertible {
    case usb20 = "USB 2.0"
    case usb30 = "USB 3.0"
    case usb31 = "USB 3.1"
    case usb32 = "USB 3.2"
    case unknown = "Unknown"

    var description: String { rawValue }

    var nominalSpeedMbps: Int {
        switch self {
        case .usb20: return 480
        case .usb30: return 5_000
        case .usb31: return 10_000
        case .usb32: return 20_000
        case .unknown: return 0
        }
    }

    func linkDescription(speedMbps: Int? = nil) -> String {
        let resolvedSpeed = speedMbps ?? nominalSpeedMbps
        guard resolvedSpeed > 0 else { return description }
        return "\(description) · \(Self.formatSpeed(resolvedSpeed))"
    }

    /// Maximum practical throughput in bytes per second used for UI clamping.
    var maxSpeedBytesPerSecond: Double {
        switch self {
        case .usb20: return 480_000_000 / 8 * 0.7
        case .usb30: return 5_000_000_000 / 8 * 0.7
        case .usb31: return 10_000_000_000 / 8 * 0.7
        case .usb32: return 20_000_000_000 / 8 * 0.7
        case .unknown: return 42_000_000
        }
    }

    private static func formatSpeed(_ speedMbps: Int) -> String {
        if speedMbps >= 1_000 {
            let speedGbps = Double(speedMbps) / 1_000
            if speedGbps.rounded() == speedGbps {
                return String(format: "%.0f Gbps", speedGbps)
            }
            return String(format: "%.1f Gbps", speedGbps)
        }

        return "\(speedMbps) Mbps"
    }
}
