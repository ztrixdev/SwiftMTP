import Foundation

struct MTPDeviceInfo: Codable, Identifiable, Hashable {
    let vendorId: UInt16
    let productId: UInt16
    let serialNumber: String
    let manufacturer: String
    let model: String
    
    /// Unique identifier used for directed connections in the Go backend.
    /// Format: "vendorId|productId|serialNumber"
    var id: String {
        return "\(vendorId)|\(productId)|\(serialNumber)"
    }
    
    /// User-friendly name to display in the UI.
    var displayName: String {
        if model.isEmpty && manufacturer.isEmpty {
            return String(localized: "Unknown Device")
        }
        if model.isEmpty {
            return manufacturer
        }
        if manufacturer.isEmpty {
            return model
        }
//        return "\(manufacturer) \(model)"
        return "\(model)"
    }
}
