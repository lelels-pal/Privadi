import Foundation

public extension Int64 {
    var privadiByteString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
